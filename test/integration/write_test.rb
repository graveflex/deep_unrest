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
            name: Faker::TvShows::TwinPeaks.location
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
    a1_val = Faker::TvShows::TwinPeaks.quote
    new_a_val = Faker::TvShows::TwinPeaks.quote

    body = {
      data: {
        survey: {
          id: survey.id,
          include: {
            questions: {
              data: [
                {
                  id: q2.id,
                  include: {
                    answers: {
                      data: [
                        {
                          id: a2.id,
                          destroy: true
                        }
                      ]
                    }
                  }
                },
                {
                  id: q1.id,
                  include: {
                    answers: {
                      data: [
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
                }
              ]
            }
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
        path: 'survey.include.questions.data[0].include.answers.data[0]' }
    ]

    assert_equal resp[:temp_ids], "[1]": new_answer.id

    assert_equal resp[:changed],
                 survey: {
                   include: {
                     questions: {
                       data: [
                         nil,
                         {
                           include: {
                             answers: {
                               data: [
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
                         }
                       ]
                     }
                   }
                 }
  end

  test 'validation errors are labeled with the correct path' do
    user = applicants(:one)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"
    q1 = questions(:one)
    q1_path = "questions.#{q1.id}"
    a1_val = "XXXXX#{Faker::TvShows::TwinPeaks.quote}"
    a2_val = "XXXXX#{Faker::TvShows::TwinPeaks.quote}"

    body = {
      data: {
        survey: {
          id: survey.id,
          attributes: {
            name: nil
          },
          include: {
            questions: {
              data: [
                {
                  id: q1.id,
                  include: {
                    answers: {
                      data: [
                        {
                          id: '[1]',
                          attributes: {
                            surveyId: survey.id,
                            value: a1_val,
                            applicantId: user.id,
                            questionId: q1.id
                          }
                        },
                        {
                          id: '[2]',
                          attributes: {
                            surveyId: survey.id,
                            value: Faker::TvShows::TwinPeaks.quote,
                            applicantId: user.id,
                            questionId: q1.id
                          }
                        },
                        {
                          id: '[3]',
                          attributes: {
                            surveyId: survey.id,
                            value: a2_val,
                            applicantId: user.id,
                            questionId: q1.id
                          }
                        }
                      ]
                    }
                  }
                }
              ]
            }
          }
        }
      }
    }

    patch '/deep_unrest/write', auth_xhr_req(body, user)
    resp = format_response

    assert_equal resp[:errors],
                 survey: {
                   attributes: {
                     name: ["can't be blank"]
                   },
                   include: {
                     questions: {
                       data: [
                         {
                           include: {
                             answers: {
                               data: [
                                 {
                                   attributes: {
                                     value: ['is invalid']
                                   }
                                 },
                                 nil,
                                 {
                                   attributes: {
                                     value: ['is invalid']
                                   }
                                 }
                               ]
                             }
                           }
                         }
                       ]
                     }
                   }
                 }
  end
end
