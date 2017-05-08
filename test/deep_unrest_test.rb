# frozen_string_literal: true

require 'test_helper'

module DeepUnrest
  class Test < ActiveSupport::TestCase
    test 'truth' do
      assert_kind_of Module, DeepUnrest
    end

    class ParsePath < ActiveSupport::TestCase
      test 'parses path for entities and ids' do
        assert_equal [['surveys', nil]],
                     DeepUnrest.parse_path('surveys')
        assert_equal [['surveys', '.123']],
                     DeepUnrest.parse_path('surveys.123')
        assert_equal [['surveys', '[123]']],
                     DeepUnrest.parse_path('surveys[123]')
        assert_equal [['surveys', '.1'],
                      ['questions', nil]],
                     DeepUnrest.parse_path('surveys.1.questions')
        assert_equal [['surveys', '.1'],
                      ['questions', '.2'],
                      ['answers', '[1]']],
                     DeepUnrest.parse_path(
                       'surveys.1.questions.2.answers[1]'
                     )
        assert_equal [['surveys', '[1]'],
                      ['questions', '[2]'],
                      ['answers', '[1]']],
                     DeepUnrest.parse_path(
                       'surveys[1].questions[2].answers[1]'
                     )
        assert_equal [['surveys', nil],
                      ['questions', nil],
                      ['answers', nil]],
                     DeepUnrest.parse_path('surveys.questions.answers')
      end
    end

    class IdentifyScopes < ActiveSupport::TestCase
      test 'derives scope type from id' do
        assert_equal :show, DeepUnrest.get_scope_type('.0')
        assert_equal :show, DeepUnrest.get_scope_type('.123')
        assert_equal :create, DeepUnrest.get_scope_type('[0]')
        assert_equal :create, DeepUnrest.get_scope_type('[123]')
        assert_equal :related, DeepUnrest.get_scope_type(nil, 1)
        assert_equal :all, DeepUnrest.get_scope_type(nil, 0)
      end

      test 'raises error if parent does not have child association' do
        question = questions(:one)
        assert_raises DeepUnrest::InvalidAssociation do
          DeepUnrest.get_scope(:related,
                               [{ type: 'questions',
                                  klass: Question,
                                  scope: question }],
                               'attachments')
        end
      end

      test 'raises error if parent and child are both collections' do
        question = questions(:one)
        assert_raises DeepUnrest::InvalidAssociation do
          DeepUnrest.get_scope(:related,
                               [{ type: 'questions',
                                  klass: Question,
                                  scope: question }],
                               'answers')
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
                     DeepUnrest.get_scope(:related,
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
                      action: :update,
                      scope_type: :update,
                      klass: Survey,
                      scope: { base: Survey,
                               method: :find,
                               arguments: [survey.id.to_s] } },
                    { type: 'surveys',
                      id: ".#{survey.id}",
                      action: nil,
                      scope_type: :show,
                      klass: Survey,
                      scope: { base: Survey,
                               method: :find,
                               arguments: [survey.id.to_s] } },
                    { type: 'questions',
                      id: ".#{q1.id}",
                      action: nil,
                      scope_type: :show,
                      klass: Question,
                      scope: { base: Question,
                               method: :find,
                               arguments: [q1.id.to_s] } },
                    { type: 'answers',
                      id: ".#{a1.id}",
                      action: :update,
                      scope_type: :update,
                      klass: Answer,
                      scope: { base: Answer,
                               method: :find,
                               arguments: [a1.id.to_s] } },
                    { type: 'answers',
                      id: '[1]',
                      action: :create,
                      scope_type: :create,
                      klass: Answer,
                      scope: nil },
                    { type: 'questions',
                      id: ".#{q2.id}",
                      action: nil,
                      scope_type: :show,
                      klass: Question,
                      scope: { base: Question,
                               method: :find,
                               arguments: [q2.id.to_s] } },
                    { type: 'answers',
                      id: ".#{a2.id}",
                      action: :destroy,
                      scope_type: :destroy,
                      klass: Answer,
                      scope: { base: Answer,
                               method: :find,
                               arguments: [a2.id.to_s] } }]

        scopes = DeepUnrest.collect_all_scopes(params)
        assert_equal expected, scopes
      end
    end

    class BuildUpdateBody < ActiveSupport::TestCase
      test 'creates a fragment of the update body using the operation path' do
        path = 'surveys.1.questions.2.answers[3].attachments[4]'
        action = :update
        value = Faker::TwinPeaks.quote
        body_part = DeepUnrest.build_mutation_fragment(path: path,
                                                       attributes: {
                                                         title: value
                                                       },
                                                       action: action)

        expected = {
          surveys: {
            klass: Survey,
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
                          id: nil,
                          attachments_attributes: [
                            {
                              id: nil,
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

        assert_equal expected, body_part
      end

      test 'marks fragments to be destroyed' do
        path = 'surveys.1.questions.2.answers[3].attachments.4'
        action = :destroy
        body_part = DeepUnrest.build_mutation_fragment(path: path,
                                                       action: action)

        expected = {
          surveys: {
            klass: Survey,
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
                          id: nil,
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
        assert_equal expected, body_part
      end

      test 'recursively merges fragments into update body' do
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

        params = [{ action: 'update',
                    path: survey_path,
                    attributes: { name: survey_name } },
                  { action: 'update',
                    path: "#{survey_path}.#{q1_path}.#{a1_path}",
                    attributes: { value: a1_val } },
                  { action: 'create',
                    path: "#{survey_path}.#{q1_path}.answers[1]",
                    attributes: { value: new_a_val } },
                  { action: 'destroy',
                    path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

        result = DeepUnrest.build_mutation_body(params)

        expected = {
          id: survey.id.to_s,
          name: survey_name,
          questions_attributes: [{
            id: q1.id.to_s,
            answers_attributes: [{
              id: a1.id.to_s,
              value: a1_val
            }]
          }, {
            id: q1.id.to_s,
            answers_attributes: [{
              id: nil,
              value: new_a_val
            }]
          }, {
            id: q2.id.to_s,
            answers_attributes: [{
              id: a2.id.to_s,
              _destroy: true
            }]
          }]
        }

        assert_equal Survey, result[:surveys][:klass]
        assert_equal expected, result[:surveys][survey.id.to_s][:update][:body]
        assert_equal :update, result[:surveys][survey.id.to_s][:update][:method]
      end
    end
  end
end
