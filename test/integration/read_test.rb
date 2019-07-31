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

  test 'nested associations are returned' do
    user = admins(:one)
    survey = surveys(:one)
    second_answer = survey.applicant.answers.last

    create_attachments(survey, 30)

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

    binding.pry
  end
end
