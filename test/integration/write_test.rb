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
    assert_equal resp[:changed], {
      survey: {
        id: survey.id.to_s,
        type: 'surveys',
        attributes: {
          approved: true
        }
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

    assert_equal resp, {
      errors: {
        survey: {
          id: survey.id,
          type: 'surveys',
          attributes: {
            approved: 'Unpermitted parameter'
          }
        }
      }
    }
  end
end
