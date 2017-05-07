# frozen_string_literal: true

require 'test_helper'

module DeepUnrest
  class Test < ActiveSupport::TestCase
    test 'truth' do
      assert_kind_of Module, DeepUnrest
    end

    test 'parses path for entities and ids' do
      assert_equal [['submissions', nil]],
                   DeepUnrest.parse_path('submissions')
      assert_equal [['submissions', '.123']],
                   DeepUnrest.parse_path('submissions.123')
      assert_equal [['submissions', '[123]']],
                   DeepUnrest.parse_path('submissions[123]')
      assert_equal [['submissions', '.1'],
                    ['questions', nil]],
                   DeepUnrest.parse_path('submissions.1.questions')
      assert_equal [['submissions', '.1'],
                    ['questions', '.2'],
                    ['answers', '[1]']],
                   DeepUnrest.parse_path('submissions.1.questions.2.answers[1]')
      assert_equal [['submissions', '[1]'],
                    ['questions', '[2]'],
                    ['answers', '[1]']],
                   DeepUnrest.parse_path(
                     'submissions[1].questions[2].answers[1]'
                   )
      assert_equal [['submissions', nil],
                    ['questions', nil],
                    ['answers', nil]],
                   DeepUnrest.parse_path('submissions.questions.answers')
    end

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

    test 'raises error if parent is collection and child is also collection' do
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
end
