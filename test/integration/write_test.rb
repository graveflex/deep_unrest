# frozen_string_literal: true

require 'test_helper'

class WriteTest < ActionDispatch::IntegrationTest
  setup do
    SurveyResource.any_instance.unstub(:track_save)
    SurveyResource.any_instance.unstub(:track_update)
    SurveyResource.any_instance.unstub(:track_create)
    SurveyResource.any_instance.unstub(:track_remove)
  end

  test 'authorized users can update a resource' do
    user = admins(:one)
    survey = surveys(:one)

    # sanity check
    assert_not survey.approved

    body = {
      data: {
        survey: {
          id: survey.id,
          attributes: {
            approved: true
          }
        }
      }
    }

    patch '/deep_unrest/write', auth_xhr_req(body, user)

    resp = format_response

    survey.reload

    assert survey.approved
    assert_equal resp[:changed],
                 survey: {
                   id: survey.id.to_s,
                   type: 'surveys',
                   attributes: {
                     approved: true
                   }
                 }
  end

  test 'users cannot update un-allowed attributes' do
    user = applicants(:one)
    survey = surveys(:one)

    body = {
      data: {
        survey: {
          id: survey.id,
          type: 'surveys',
          attributes: {
            approved: true,
            name: Faker::TwinPeaks.location
          }
        }
      }
    }

    patch '/deep_unrest/write', auth_xhr_req(body, user)

    assert_response 405
    resp = format_response

    assert_equal resp,
                 errors: {
                   survey: {
                     id: survey.id,
                     type: 'surveys',
                     attributes: {
                       approved: 'Unpermitted parameter'
                     }
                   }
                 }
  end

  test 'authorized users can update deeply nested resources' do
    user = applicants(:one)
    survey = surveys(:one)
    q1 = questions(:one)
    q2 = questions(:two)
    a1 = answers(:one)
    a2 = answers(:two)
    a2_attachments = a2.attachments
    a1_val = Faker::TwinPeaks.quote
    new_a_val = Faker::TwinPeaks.quote

    body = {
      data: {
        survey: {
          id: survey.id,
          include: {
            questions: [
              {
                id: q2.id,
                include: {
                  answers: [
                    {
                      id: a2.id,
                      destroy: true
                    }
                  ]
                }
              },
              {
                id: q1.id,
                include: {
                  answers: [
                    {
                      id: a1.id,
                      attributes: {
                        value: a1_val
                      }
                    },
                    {
                      id: '[1]',
                      attributes: {
                        value: new_a_val,
                        applicantId: user.id,
                        surveyId: survey.id,
                        questionId: q1.id
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    }

    patch '/deep_unrest/write', auth_xhr_req(body, user)
    resp = format_response

    new_answer = Answer.last

    assert_equal resp[:destroyed], [
      { type: 'answers',
        id: a2.id,
        path: 'survey.include.questions[0].include.answers[0]' }
    ]

    assert_equal resp[:temp_ids], "[1]": new_answer.id

    assert_equal resp[:changed],
                 survey: {
                   include: {
                     questions: [
                       nil,
                       {
                         include: {
                           answers: [
                             {
                               id: a1.id.to_s,
                               type: 'answers',
                               attributes: {
                                 value: a1_val
                               }
                             },
                             {
                               id: new_answer.id.to_s,
                               type: 'answers',
                               attributes: {
                                 value: new_a_val,
                                 applicantId: user.id,
                                 surveyId: survey.id,
                                 questionId: q1.id
                               }
                             }
                           ]
                         }
                       }
                     ]
                   }
                 }
  end
end
