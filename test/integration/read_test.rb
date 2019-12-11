# frozen_string_literal: true

require 'test_helper'

class ReadTest < ActionDispatch::IntegrationTest
  setup do
    SurveyResource.any_instance.unstub(:track_save)
    SurveyResource.any_instance.unstub(:track_update)
    SurveyResource.any_instance.unstub(:track_create)
    SurveyResource.any_instance.unstub(:track_remove)
  end

  def create_attachments(survey, count)
    survey.answers.each do |answer|
      count.times do
        Attachment.create!(applicant: survey.applicant,
                           answer: answer)
      end
    end
  end

  test 'requested data is returned' do
    user = admins(:one)
    survey = surveys(:one)
    params = {
      survey: {
        id: survey.id,
        fields: ['name']
      }
    }

    get '/deep_unrest/read', auth_xhr_req({ data: params }, user, false)
    resp = format_response

    assert_equal resp.dig(:survey, :id), survey.id.to_s
    assert_equal resp.dig(:survey, :type), 'surveys'
    assert_equal resp.dig(:survey, :attributes), name: survey.name
  end

  test 'before_read is called' do
    user = applicants(:one)
    user.name = 'homer'
    user.save!

    params = {
      surveys: {
        fields: [:name]
      }
    }

    assert_raises Pundit::NotAuthorizedError do
      get '/deep_unrest/read', auth_xhr_req({ data: params }, user, false)
    end
  end

  test 'context is passed to before_read' do
    user = applicants(:one)

    params = {
      surveys: {
        fields: [:name]
      }
    }

    assert_raises Pundit::NotAuthorizedError do
      get '/deep_unrest/read', auth_xhr_req({ data: params,
                                              context: { block_me: true } },
                                            user,
                                            false)
    end
  end

  test 'original resource scope is preserved' do
    user = admins(:one)
    stimpy = Applicant.create!(name: 'Stimpson J Cat',
                               email: 'stimp@test.com',
                               nickname: '_stimpy_',
                               password: 'secret123',
                               password_confirmation: 'secret123')

    stimpy = Applicant.create!(name: 'Ren Hoek',
                               email: 'ren@test.com',
                               nickname: '_ren_',
                               password: 'secret123',
                               password_confirmation: 'secret123')

    params = {
      applicants: {
        fields: %w[name nickname]
      }
    }

    get '/deep_unrest/read', auth_xhr_req({ data: params }, user, false)
    resp = format_response

    nicknames = resp[:applicants][:data].map { |a| a[:attributes][:nickname] }

    refute nicknames.include? '_stimpy_'
    assert nicknames.include? '_ren_'
  end

  test 'nested associations are returned' do
    user = admins(:one)
    survey = surveys(:one)
    second_answer = survey.applicant.answers.last

    create_attachments(survey, 30)

    stimpy = Applicant.create!(name: 'Stimpson J Cat',
                               email: 'stimp@test.com',
                               nickname: '_stimpy_',
                               password: 'secret123',
                               password_confirmation: 'secret123')

    stimpy = Applicant.create!(name: 'Ren Hoek',
                               email: 'ren@test.com',
                               nickname: '_ren_',
                               password: 'secret123',
                               password_confirmation: 'secret123')

    params = {
      survey: {
        id: survey.id,
        fields: %w[name applicantId],
        include: {
          applicant: {
            id: { fromContext: 'survey.applicantId' },
            fields: %w[name email],
            include: {
              answers: {
                filter: { applicantId: { fromContext: 'applicant.id' },
                          surveyId: { fromContext: 'survey.id' } },
                fields: %w[applicantId surveyId value],
                include: {
                  attachments: {
                    filter: { answerId: { fromContext: 'answer.id' },
                              applicantId: { fromContext: 'applicant.id' } },
                    fields: %w[answerId fileUid applicantId],
                    sort: [{ field: 'id', direction: 'asc' }],
                    paginate: { page: 1, size: 3 },
                    extend: {
                      "#{second_answer.id}": {
                        paginate: { size: 4 },
                        sort: [{ field: 'id', direction: 'desc' }]
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      applicant: {
        id: user.id,
        fields: %w[name nickname]
      },
      questions: {
        fields: %w[content surveyId],
        paginate: { page: 1, size: 1 }
      }
    }

    get '/deep_unrest/read', auth_xhr_req({ data: params }, user, false)
    resp = format_response

    assert_equal(survey.id, resp[:survey][:id].to_i)

    get '/applicants'
    resp = format_response

    nicknames = resp[:data].map { |a| a[:attributes][:nickname] }
    refute nicknames.include? '_stimpy_'
    assert nicknames.include? '_ren_'
  end
end
