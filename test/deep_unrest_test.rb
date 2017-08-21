# frozen_string_literal: true

require 'test_helper'

def match_to_h(m)
  Hash[m.names.map(&:to_sym).zip(m.captures)]
end

def scan_to_h(m)
  m.map { |(type, id)| { type: type, id: id } }
end

module DeepUnrest
  class Test < ActiveSupport::TestCase
    test 'truth' do
      assert_kind_of Module, DeepUnrest
    end

    class ParsePath < ActiveSupport::TestCase
      test 'parses path for entities and ids' do
        match1 = DeepUnrest.parse_path('surveys.*')
        match2 = DeepUnrest.parse_path('surveys.123')
        match3 = DeepUnrest.parse_path('surveys[test-123]')
        match4 = DeepUnrest.parse_path('surveys[1].questions.*')
        match5 = DeepUnrest.parse_path('surveys.1.questions.2.answers[1]')
        match6 = DeepUnrest.parse_path('surveys.*.questions.*.answers.*')

        assert_equal scan_to_h(match1), [{ type: 'surveys',
                                           id: '.*' }]
        assert_equal scan_to_h(match2), [{ type: 'surveys',
                                           id: '.123' }]
        assert_equal scan_to_h(match3), [{ type: 'surveys',
                                           id: '[test-123]' }]
        assert_equal scan_to_h(match4), [{ type: 'surveys',
                                           id: '[1]' },
                                         { type: 'questions',
                                           id: '.*' }]
        assert_equal scan_to_h(match5), [{ type: 'surveys',
                                           id: '.1' },
                                         { type: 'questions',
                                           id: '.2' },
                                         { type: 'answers',
                                           id: '[1]' }]
        assert_equal scan_to_h(match6), [{ type: 'surveys',
                                           id: '.*' },
                                         { type: 'questions',
                                           id: '.*' },
                                         { type: 'answers',
                                           id: '.*' }]
      end

      test 'throws errors when path is invalid' do
        assert_raises DeepUnrest::InvalidPath do
          DeepUnrest.parse_path('answers.questions.2')
        end
      end
    end

    class ParseErrorInfo < ActiveSupport::TestCase
      test 'parses error key to correlate with operation path' do
        match1 = DeepUnrest.parse_error_path('surveys[0].name')
        match2 = DeepUnrest.parse_error_path('surveys[1].questions[2].baz')
        match3 = DeepUnrest.parse_error_path('surveys[1].qs[2].answers[1].val')
        match4 = DeepUnrest.parse_error_path('surveys[1].nested.val')
        match5 = DeepUnrest.parse_error_path('nested.val')

        assert_equal({ path: 'surveys[0]', field: 'name' },
                     match_to_h(match1))
        assert_equal({ path: 'surveys[1].questions[2]', field: 'baz' },
                     match_to_h(match2))
        assert_equal({ path: 'surveys[1].qs[2].answers[1]', field: 'val' },
                     match_to_h(match3))
        assert_equal({ path: 'surveys[1]', field: 'nested.val' },
                     match_to_h(match4))
        assert_equal({ path: nil, field: 'nested.val' },
                     match_to_h(match5))
      end
    end

    class IdentifyScopes < ActiveSupport::TestCase
      test 'derives scope type from id' do
        assert_equal :show, DeepUnrest.get_scope_type('.0', false, false)
        assert_equal :show, DeepUnrest.get_scope_type('.123', false, false)
        assert_equal :show, DeepUnrest.get_scope_type('.abcdef', false, false)
        assert_equal :update, DeepUnrest.get_scope_type('.abcdef', true, false)
        assert_equal :destroy, DeepUnrest.get_scope_type('.abcdef', true, true)
        assert_equal :create, DeepUnrest.get_scope_type('[0]', false, false)
        assert_equal :create, DeepUnrest.get_scope_type('[123]', false, false)
        assert_equal :index, DeepUnrest.get_scope_type('.*', false, false)
        assert_equal :update_all, DeepUnrest.get_scope_type('.*', true, false)
        assert_equal :destroy_all, DeepUnrest.get_scope_type('.*', true, true)

        assert_raises DeepUnrest::InvalidId do
          DeepUnrest.get_scope_type('dingus', false, false)
        end
      end

      test 'throws errors for invalid associations' do
        survey = surveys(:one)
        survey_path = "surveys.#{survey.id}"
        q1 = questions(:one)
        q1_path = "questions.#{q1.id}"

        assert_raises DeepUnrest::InvalidAssociation do
          params = [{ action: 'update',
                      path: "#{survey_path}.#{q1_path}.admins[2]",
                      attributes: { description: 'option 1' } }]
          DeepUnrest.collect_all_scopes(params)
        end
      end

      test 'returns scope for entity by id' do
        answer = answers(:one)
        expected = { base: Answer, method: :find, arguments: [answer.id.to_s] }
        assert_equal expected,
                     DeepUnrest.get_scope(:show, [], 'answers', ".#{answer.id}")
      end

      test 'returns scope for entity within parent association' do
        survey = surveys(:one)
        expected = { base: survey, method: :questions }
        assert_equal expected,
                     DeepUnrest.get_scope(:update_all,
                                          [{ type: 'surveys',
                                             klass: Survey,
                                             scope: survey,
                                             id: survey.id }],
                                          'questions')
      end

      test 'returns scope of all entities when no parent is present' do
        expected = { base: Survey, method: :all }
        assert_equal expected,
                     DeepUnrest.get_scope(:all, [], 'surveys')
      end
    end

    class CollectScopes < ActiveSupport::TestCase
      test 'all scopes are collected from actions' do
        survey = surveys(:one)
        survey_path = "surveys.#{survey.id}"
        q1 = questions(:one)
        q1_path = "questions.#{q1.id}"
        q2 = questions(:two)
        q2_path = "questions.#{q2.id}"
        a1 = answers(:one)
        a1_path = "answers.#{a1.id}"
        a2 = answers(:two)
        a2_path = "answers.#{a2.id}"

        params = [{ action: 'update',
                    path: survey_path,
                    attributes: { name: 'xyz' } },
                  { action: 'update',
                    path: "#{survey_path}.#{q1_path}.#{a1_path}",
                    attributes: { value: 'option 1' } },
                  { action: 'create',
                    path: "#{survey_path}.#{q1_path}.answers[1]",
                    attributes: { value: 'option 2' } },
                  { action: 'destroy',
                    path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

        expected = [{ type: 'surveys',
                      id: ".#{survey.id}",
                      scope_type: :update,
                      klass: Survey,
                      path: survey_path,
                      index: 0,
                      error_path: nil,
                      scope: { base: Survey,
                               method: :find,
                               arguments: [survey.id.to_s] } },
                    { type: 'surveys',
                      id: ".#{survey.id}",
                      scope_type: :show,
                      klass: Survey,
                      error_path: nil,
                      scope: { base: Survey,
                               method: :find,
                               arguments: [survey.id.to_s] } },
                    { type: 'questions',
                      id: ".#{q1.id}",
                      scope_type: :show,
                      klass: Question,
                      error_path: nil,
                      scope: { base: Question,
                               method: :find,
                               arguments: [q1.id.to_s] } },
                    { type: 'answers',
                      id: ".#{a1.id}",
                      scope_type: :update,
                      path: "#{survey_path}.#{q1_path}.#{a1_path}",
                      index: 0,
                      klass: Answer,
                      error_path: nil,
                      scope: { base: Answer,
                               method: :find,
                               arguments: [a1.id.to_s] } },
                    { type: 'answers',
                      id: '[1]',
                      scope_type: :create,
                      path: "#{survey_path}.#{q1_path}.answers[1]",
                      index: 1,
                      klass: Answer,
                      error_path: nil,
                      scope: nil },
                    { type: 'questions',
                      id: ".#{q2.id}",
                      scope_type: :show,
                      klass: Question,
                      error_path: nil,
                      scope: { base: Question,
                               method: :find,
                               arguments: [q2.id.to_s] } },
                    { type: 'answers',
                      id: ".#{a2.id}",
                      scope_type: :update,
                      path: "#{survey_path}.#{q2_path}.#{a2_path}",
                      index: 2,
                      klass: Answer,
                      error_path: nil,
                      scope: { base: Answer,
                               method: :find,
                               arguments: [a2.id.to_s] } }]

        scopes = DeepUnrest.collect_all_scopes(params)

        assert_equal expected, scopes
      end
    end

    class BuildUpdateBody < ActiveSupport::TestCase
      test 'creates a fragment of the update body using the operation path' do
        user = applicants(:one)
        path = 'surveys.1.questions.2.answers[3].attachments[4]'
        action = :update
        value = Faker::TwinPeaks.quote
        params = [{ path: path,
                    attributes: { title: value },
                    action: action }]
        scopes = DeepUnrest.collect_all_scopes(params)
        body_part = DeepUnrest.build_mutation_fragment(params.first,
                                                       scopes,
                                                       user,
                                                       {})

        expected = {
          surveys: {
            klass: Survey,
            operations: {
              '1' => {
                update: {
                  method: :update,
                  body: {
                    id: '1',
                    questions_attributes: [
                      {
                        id: '2',
                        answers_attributes: [
                          {
                            id: '[3]',
                            attachments_attributes: [
                              {
                                id: '[4]',
                                title: value
                              }
                            ]
                          }
                        ]
                      }
                    ]
                  }
                }
              }
            }
          }
        }

        assert_equal expected, body_part
      end

      test 'does not treat normal arrays as nested resources' do
        user = admins(:one)
        path = 'surveys.1.questions.2'
        action = :update
        content = Faker::TwinPeaks.quote
        options = [Faker::TwinPeaks.location,
                   Faker::TwinPeaks.location]
        params = [{ path: path,
                    attributes: { content: content,
                                  options: options },
                    action: action }]
        scopes = DeepUnrest.collect_all_scopes(params)
        body_part = DeepUnrest.build_mutation_fragment(params.first,
                                                       scopes,
                                                       user,
                                                       {})

        expected = {
          surveys: {
            klass: Survey,
            operations: {
              '1' => {
                update: {
                  method: :update,
                  body: {
                    id: '1',
                    questions_attributes: [
                      {
                        id: '2',
                        options: options,
                        content: content
                      }
                    ]
                  }
                }
              }
            }
          }
        }

        assert_equal expected, body_part
      end

      test 'marks fragments to be destroyed' do
        user = applicants(:one)
        path = 'surveys.1.questions.2.answers[3].attachments.4'

        params = [{ path: path,
                    destroy: true }]
        scopes = DeepUnrest.collect_all_scopes(params)
        body_part = DeepUnrest.build_mutation_fragment(params.first,
                                                       scopes,
                                                       user,
                                                       {})

        expected = {
          surveys: {
            klass: Survey,
            operations: {
              '1' => {
                update: {
                  method: :update,
                  body: {
                    id: '1',
                    questions_attributes: [
                      {
                        id: '2',
                        answers_attributes: [
                          {
                            id: '[3]',
                            attachments_attributes: [
                              {
                                id: '4',
                                _destroy: true
                              }
                            ]
                          }
                        ]
                      }
                    ]
                  }
                }
              }
            }
          }
        }

        assert_equal expected, body_part
      end

      test 'recursively merges fragments into update body' do
        user = applicants(:one)
        survey = surveys(:one)
        survey_path = "surveys.#{survey.id}"
        q1 = questions(:one)
        q1_path = "questions.#{q1.id}"
        q2 = questions(:two)
        q2_path = "questions.#{q2.id}"
        a1 = answers(:one)
        a1_path = "answers.#{a1.id}"
        a2 = answers(:two)
        a2_path = "answers.#{a2.id}"
        survey_name = Faker::TwinPeaks.location
        a1_val = Faker::TwinPeaks.quote
        new_a_val = Faker::TwinPeaks.quote

        params = [{ path: survey_path,
                    attributes: { name: survey_name } },
                  { path: "#{survey_path}.#{q1_path}.#{a1_path}",
                    attributes: { value: a1_val } },
                  { path: "#{survey_path}.#{q1_path}.answers[1]",
                    attributes: { value: new_a_val } },
                  { destroy: true,
                    path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

        scopes = DeepUnrest.collect_all_scopes(params)

        result = DeepUnrest.build_mutation_body(params, scopes, user)

        expected = HashWithIndifferentAccess.new(
          id: survey.id.to_s,
          name: survey_name,
          questions_attributes: [{ id: q1.id.to_s,
                                   answers_attributes: [
                                     {
                                       id: a1.id.to_s,
                                       value: a1_val
                                     },
                                     {
                                       id: '[1]',
                                       value: new_a_val
                                     }
                                   ] },
                                 { id: q2.id.to_s,
                                   answers_attributes: [{
                                     id: a2.id.to_s,
                                     _destroy: true
                                   }] }]
        )

        assert_equal Survey, result[:surveys][:klass]
        assert_equal expected, result[:surveys][:operations][survey.id.to_s][:update][:body]
        assert_equal :update, result[:surveys][:operations][survey.id.to_s][:update][:method]
      end
    end

    class ReplaceTempIdsInRedirect < ActiveSupport::TestCase
      test 'temp ids are replaced in the redirect url' do
        map = { '[123]': 456, '[789]': 'xyz' }
        redirect = '/resource/[123]/nested/[789]'
        replace_proc = DeepUnrest.build_redirect_regex(map)
        assert_equal '/resource/456/nested/xyz', replace_proc.call(redirect)
      end

      test 'redirect is unaffected when no redirects are present' do
        redirect = '/resource/123/nested/4567'
        replace_proc = DeepUnrest.build_redirect_regex(nil)
        assert_equal redirect, replace_proc.call(redirect)
      end
    end
  end
end
