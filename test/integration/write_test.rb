# frozen_string_literal: true

require 'test_helper'

class WriteTest < ActionDispatch::IntegrationTest
  setup do
    SurveyResource.any_instance.unstub(:track_save)
    SurveyResource.any_instance.unstub(:track_update)
    SurveyResource.any_instance.unstub(:track_create)
    SurveyResource.any_instance.unstub(:track_remove)
  end

  test 'authorized users can make bulk updates to resources' do
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
end
