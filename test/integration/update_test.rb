# frozen_string_literal: true

require 'test_helper'

class UpdateTest < ActionDispatch::IntegrationTest
  setup do
    SurveyResource.any_instance.unstub(:track_save)
    SurveyResource.any_instance.unstub(:track_update)
    SurveyResource.any_instance.unstub(:track_create)
    SurveyResource.any_instance.unstub(:track_remove)
  end

  test 'authorization is performed when making updates' do
    user = applicants(:two)
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

    body = [{ path: survey_path,
              attributes: { name: survey_name } },
            { path: "#{survey_path}.#{q1_path}.#{a1_path}",
              attributes: { value: a1_val } },
            { path: "#{survey_path}.#{q1_path}.answers[1]",
              attributes: { value: new_a_val } },
            { destroy: true,
              path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

    expected_error = "Applicant with id '#{user.id}' is not authorized to "\
                     "update Survey with id '#{survey.id}'"

    patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)

    assert_response 403
    assert_equal expected_error, JSON.parse(response.body)[0]['title']
    assert_equal survey_path, JSON.parse(response.body)[0]['source']['pointer']
  end

  test 'before_update is called' do
    user = applicants(:one)
    user.name = 'homer'
    user.save!
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"

    body = [{ path: survey_path,
              attributes: { name: Faker::TwinPeaks.quote } }]

    assert_raises Pundit::NotAuthorizedError do
      patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)
    end
  end

  test 'context is passed to before_update' do
    user = applicants(:one)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"

    body = [{ path: survey_path,
              attributes: { name: Faker::TwinPeaks.quote } }]

    assert_raises Pundit::NotAuthorizedError do
      patch '/deep_unrest/update',
            auth_xhr_req({ data: body, context: { block_me: true } }, user)
    end
  end

  test 'callbacks have access to current user' do
    user = applicants(:one)
    user.active = false
    user.save!
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

    body = [{ path: survey_path,
              attributes: { name: survey_name } },
            { path: "#{survey_path}.#{q1_path}.#{a1_path}",
              attributes: { value: a1_val } },
            { path: "#{survey_path}.#{q1_path}.answers[1]",
              attributes: { value: new_a_val } },
            { destroy: true,
              path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

    assert_no_difference 'Answer.count' do
      assert_raises Pundit::NotAuthorizedError do
        patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)
      end
    end
  end

  test 'jsonapi resource callbacks are called on save' do
    user = applicants(:one)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"
    survey_name = Faker::TwinPeaks.location

    SurveyResource.any_instance.expects(:track_save).once
    SurveyResource.any_instance.expects(:track_update).once
    SurveyResource.any_instance.expects(:track_create).never
    SurveyResource.any_instance.expects(:track_remove).never

    body = [{ path: survey_path,
              attributes: { name: survey_name } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)
  end

  test 'jsonapi resource callbacks are called on create' do
    user = applicants(:one)
    survey_path = 'surveys[123]'
    survey_name = Faker::TwinPeaks.location

    SurveyResource.any_instance.expects(:track_save).once
    SurveyResource.any_instance.expects(:track_update).never
    SurveyResource.any_instance.expects(:track_create).once
    SurveyResource.any_instance.expects(:track_remove).never

    body = [{ path: survey_path,
              attributes: { name: survey_name,
                            applicantId: user.id } }]

    assert_difference 'Survey.count', 1 do
      patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)
    end
  end

  test 'jsonapi resource callbacks are called on destroy' do
    user = applicants(:one)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"

    SurveyResource.any_instance.expects(:track_save).never
    SurveyResource.any_instance.expects(:track_update).never
    SurveyResource.any_instance.expects(:track_create).never
    SurveyResource.any_instance.expects(:track_remove).once

    body = [{ path: survey_path,
              destroy: true }]

    assert_difference 'Survey.count', -1 do
      patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)
    end
  end

  test 'temp_ids are mapped to the ids of the created resources' do
    user = applicants(:one)
    survey = surveys(:one)
    q1 = questions(:one)
    q1_path = "questions.#{q1.id}"
    q2 = questions(:two)
    q2_path = "questions.#{q2.id}"
    a1_val = Faker::TwinPeaks.quote
    a2_val = Faker::TwinPeaks.quote
    a3_val = Faker::TwinPeaks.quote

    survey_path = "surveys.#{survey.id}"

    body = [{ path: "#{survey_path}.#{q1_path}.answers[answer1]",
              attributes: { value: a1_val,
                            applicantId: user.id,
                            surveyId: survey.id } },
            { path: "#{survey_path}.#{q1_path}.answers[answer2]",
              attributes: { value: a2_val,
                            applicantId: user.id,
                            surveyId: survey.id } },
            { path: "#{survey_path}.#{q2_path}.answers[answer3]",
              attributes: { value: a3_val,
                            applicantId: user.id,
                            surveyId: survey.id } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)

    assert_response 200

    temp_ids = JSON.parse(response.body)['tempIds']

    temp_id_map = DeepUnrest::ApplicationController.class_variable_get(
      '@@temp_ids'
    )

    assert_equal a1_val, Answer.find(temp_ids['[answer1]']).value
    assert_equal a2_val, Answer.find(temp_ids['[answer2]']).value
    assert_equal a3_val, Answer.find(temp_ids['[answer3]']).value

    # ensure temp_id_map was cleared
    assert_equal temp_id_map, {}
  end

  test 'authorized users can make bulk updates to resources' do
    user = admins(:one)
    survey1 = surveys(:one)
    survey2 = surveys(:one)

    # sanity check
    refute survey1.approved
    refute survey2.approved

    body = [{ path: 'surveys.*',
              attributes: { approved: true } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body },
                                              user)

    survey1.reload
    survey2.reload

    assert survey1.approved
    assert survey2.approved
  end

  test 'authorized users can destroy resources in bulk' do
    user = admins(:one)
    survey1 = surveys(:one)
    survey2 = surveys(:one)

    # sanity check
    refute survey1.approved
    refute survey2.approved

    body = [{ path: 'surveys.*',
              destroy: true }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body },
                                              user)

    assert_raises ActiveRecord::RecordNotFound do
      survey1.reload
    end
    assert_raises ActiveRecord::RecordNotFound do
      survey2.reload
    end

    assert_equal 0, Survey.count
  end

  test 'authorized users can only destroy resources within their scope' do
    user = applicants(:one)
    survey1 = surveys(:one)
    survey2 = surveys(:two)

    body = [{ path: 'surveys.*',
              destroy: true }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body },
                                              user)

    assert_raises ActiveRecord::RecordNotFound do
      survey1.reload
    end

    survey2.reload

    assert_equal 1, Survey.count
  end

  test 'users cannot update un-allowed attributes' do
    user = applicants(:one)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"

    body = [{ path: survey_path,
              attributes: { name: Faker::TwinPeaks.location,
                            approved: true } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body },
                                              user)

    err = JSON.parse(response.body)[0]['title']
    expected_error = 'Attributes [:approved] of Survey not allowed '\
                     "to Applicant with id '#{user.id}'"

    assert_response 405
    assert_equal expected_error, err
  end

  test 'users can only batch update resources within their scope' do
    user = applicants(:one)
    survey1 = surveys(:one)
    survey2 = surveys(:two)
    name = Faker::TwinPeaks.location

    body = [{ path: 'surveys.*',
              attributes: { name: name } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body },
                                              user)

    survey1.reload
    survey2.reload

    assert_equal name, survey1.name
    refute_equal name, survey2.name
  end

  test 'users can update deeply nested resources that they have access to' do
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
    a1_val = Faker::TwinPeaks.quote
    new_a_val = Faker::TwinPeaks.quote

    body = [{ path: "#{survey_path}.#{q1_path}.#{a1_path}",
              attributes: { value: a1_val } },
            { path: "#{survey_path}.#{q1_path}.answers[1]",
              attributes: { value: new_a_val,
                            applicantId: user.id,
                            surveyId: survey.id,
                            questionId: q1.id } },
            { destroy: true,
              path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

    redirect = "/surveys/#{survey.id}?include=questions,questions.answers"
    patch '/deep_unrest/update', auth_xhr_req({ data: body,
                                                redirect: redirect },
                                              user)

    # existing record was updated
    a1.reload
    assert_equal a1_val, a1.value

    # existing record was removed
    assert_raises ActiveRecord::RecordNotFound do
      a2.reload
    end

    # new record was created
    assert_equal Answer.last.value, new_a_val

    assert_response :success

    resp_redirect = JSON.parse(response.body)['redirect']
    assert_equal redirect, resp_redirect
  end

  test 'users cannot update attributes that they do not have access to' do
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
    a1_val = Faker::TwinPeaks.quote
    new_a_val = Faker::TwinPeaks.quote
    q1_val = Faker::TwinPeaks.quote

    body = [{ path: "#{survey_path}.#{q1_path}.#{a1_path}",
              attributes: { value: a1_val } },
            { path: "#{survey_path}.#{q1_path}",
              attributes: { content: q1_val } },
            { path: "#{survey_path}.#{q1_path}.answers[1]",
              attributes: { value: new_a_val,
                            applicant_id: user.id,
                            survey_id: survey.id,
                            question_id: q1.id } },
            { destroy: true,
              path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)

    assert_response 403
  end

  test 'validation errors are labeled with the correct path' do
    user = applicants(:one)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"
    q1 = questions(:one)
    q1_path = "questions.#{q1.id}"
    a1_val = "XXXXX#{Faker::TwinPeaks.quote}"
    a2_val = "XXXXX#{Faker::TwinPeaks.quote}"

    body = [{ path: survey_path,
              attributes: { name: nil } },
            { path: "#{survey_path}.#{q1_path}.answers[1]",
              attributes: { surveyId: survey.id,
                            value: a1_val,
                            applicantId: user.id,
                            questionId: q1.id } },
            { path: "#{survey_path}.#{q1_path}.answers[2]",
              attributes: { surveyId: survey.id,
                            value: Faker::TwinPeaks.quote,
                            applicantId: user.id,
                            questionId: q1.id } },
            { path: "#{survey_path}.#{q1_path}.answers[3]",
              attributes: { surveyId: survey.id,
                            value: a2_val,
                            applicantId: user.id,
                            questionId: q1.id } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)

    expected_results = [{ title: 'Value is invalid',
                          detail: 'is invalid',
                          source: { pointer: "surveys.#{survey.id}"\
                                             ".questions.#{q1.id}"\
                                             '.answers[1].value',
                                    deepUnrestPath: "surveys.#{survey.id}"\
                                                    ".questions.#{q1.id}"\
                                                    '.answers[1].value',
                                    activeRecordPath: 'questions[0]'\
                                                      '.answers[0].value' } },
                        { title: 'Value is invalid',
                          detail: 'is invalid',
                          source: { pointer: "surveys.#{survey.id}"\
                                             ".questions.#{q1.id}"\
                                             '.answers[3].value',
                                    deepUnrestPath: "surveys.#{survey.id}"\
                                                    ".questions.#{q1.id}"\
                                                    '.answers[3].value',
                                    activeRecordPath: 'questions[0]'\
                                                      '.answers[2].value' } },
                        { title: "Name can\'t be blank",
                          detail: "can't be blank",
                          source: { pointer: "#{survey_path}.name",
                                    deepUnrestPath: "#{survey_path}.name",
                                    activeRecordPath: 'name' } }]

    errors = JSON.parse(response.body)['errors'].map do |e|
      ActiveSupport::HashWithIndifferentAccess.new(e).deep_symbolize_keys
    end

    temp_id_map = DeepUnrest::ApplicationController.class_variable_get(
      '@@temp_ids'
    )

    assert_response 409
    assert_equal expected_results, errors

    # ensure temp id map is cleared when errors are thrown
    assert_equal temp_id_map, {}
  end

  test 'validation errors can use paths defined by clients' do
    user = applicants(:one)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"
    q1 = questions(:one)
    q1_path = "questions.#{q1.id}"
    q2 = questions(:two)
    q2_path = "questions.#{q2.id}"
    a0_val = Faker::TwinPeaks.quote
    a1_val = Faker::TwinPeaks.quote
    a2_val = "XXXXX#{Faker::TwinPeaks.quote}"
    a3_val = Faker::TwinPeaks.quote
    a4_val = "XXXXX#{Faker::TwinPeaks.quote}"
    survey_error_path = Faker::Lorem.word
    answer_0_error_path = 'answer_0_error_path'
    answer_1_error_path = 'answer_1_error_path'
    answer_2_error_path = 'answer_2_error_path'
    answer_4_error_path = 'answer_4_error_path'

    body = [{ path: survey_path,
              errorPath: survey_error_path,
              attributes: { name: nil } },
            { path: "#{survey_path}.#{q1_path}.answers[0]",
              errorPath: answer_0_error_path,
              attributes: { surveyId: survey.id,
                            value: a0_val,
                            applicantId: user.id,
                            questionId: q1.id } },
            { path: "#{survey_path}.#{q1_path}.answers[1]",
              destroy: true,
              errorPath: answer_1_error_path,
              attributes: { surveyId: survey.id,
                            value: a1_val,
                            applicantId: user.id,
                            questionId: q1.id } },
            { path: "#{survey_path}.#{q1_path}.answers[2]",
              errorPath: answer_2_error_path,
              attributes: { surveyId: survey.id,
                            value: a2_val,
                            applicantId: user.id,
                            questionId: q1.id } },
            { path: "#{survey_path}.#{q1_path}.answers[3]",
              attributes: { surveyId: survey.id,
                            value: a3_val,
                            applicantId: user.id,
                            questionId: q1.id } },
            { path: "#{survey_path}.#{q2_path}.answers[4]",
              errorPath: answer_4_error_path,
              attributes: { surveyId: survey.id,
                            value: a4_val,
                            applicantId: user.id,
                            questionId: q1.id } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)

    expected_results = [{ title: 'Value is invalid',
                          detail: 'is invalid',
                          source: { pointer: "#{answer_2_error_path}.value",
                                    deepUnrestPath: "#{survey_path}."\
                                                    "#{q1_path}."\
                                                    'answers[2].value',
                                    activeRecordPath: 'questions[0].'\
                                                      'answers[1].value' } },
                        { title: 'Value is invalid',
                          detail: 'is invalid',
                          source: { pointer: "#{answer_4_error_path}.value",
                                    deepUnrestPath: "#{survey_path}."\
                                                    "#{q2_path}."\
                                                    'answers[4].value',
                                    activeRecordPath: 'questions[1].'\
                                                      'answers[0].value' } },

                        { title: "Name can\'t be blank",
                          detail: "can't be blank",
                          source: { pointer: "#{survey_error_path}.name",
                                    deepUnrestPath: "#{survey_path}.name",
                                    activeRecordPath: 'name' } }]

    errors = JSON.parse(response.body)['errors'].map do |e|
      ActiveSupport::HashWithIndifferentAccess.new(e).deep_symbolize_keys
    end

    assert_response 409
    assert_equal expected_results, errors
  end

  test 'replaces temp_ids in redirects with new actual ids' do
    user = applicants(:one)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"
    q1 = questions(:one)
    q1_path = "questions.#{q1.id}"
    a1_val = Faker::TwinPeaks.quote
    a2_val = Faker::TwinPeaks.quote
    att1_uid = Faker::Pokemon.name
    att2_uid = Faker::Pokemon.name
    att3_uid = Faker::Pokemon.name

    body = [{ path: "#{survey_path}.#{q1_path}.answers[a1]",
              attributes: { value: a1_val,
                            applicantId: user.id,
                            surveyId: survey.id } },
            { path: "#{survey_path}.#{q1_path}.answers[a2]",
              attributes: { value: a2_val,
                            applicantId: user.id,
                            surveyId: survey.id } },
            { path: "#{survey_path}.#{q1_path}.answers[a1].attachments[att1]",
              attributes: { fileUid: att1_uid,
                            applicantId: user.id } },
            { path: "#{survey_path}.#{q1_path}.answers[a2].attachments[att2]",
              attributes: { fileUid: att2_uid,
                            applicantId: user.id } },
            { path: "#{survey_path}.#{q1_path}.answers[a1].attachments[att3]",
              attributes: { fileUid: att3_uid,
                            applicantId: user.id } }]

    patch '/deep_unrest/update',
          auth_xhr_req({ data: body,
                         redirect: '/[a1]/[a2]/[att1]/[att2]/[att3]' },
                       user)

    resp = JSON.parse(response.body)

    redirect = resp['redirect']
    new_a1_id = resp['tempIds']['[a1]']
    new_a2_id = resp['tempIds']['[a2]']
    new_att1_id = resp['tempIds']['[att1]']
    new_att2_id = resp['tempIds']['[att2]']
    new_att3_id = resp['tempIds']['[att3]']

    assert_response :success
    assert_equal "/#{new_a1_id}/#{new_a2_id}/#{new_att1_id}/#{new_att2_id}/"\
                 "#{new_att3_id}",
                 redirect

    assert_equal a1_val, Answer.find(new_a1_id).value
    assert_equal a2_val, Answer.find(new_a2_id).value
    assert_equal att1_uid, Attachment.find(new_att1_id).file_uid
    assert_equal att2_uid, Attachment.find(new_att2_id).file_uid
    assert_equal att3_uid, Attachment.find(new_att3_id).file_uid
  end

  test 'simple destroy' do
    user = applicants(:one)
    survey = surveys(:one)
    questions = survey.questions.as_json
    answers = survey.questions.as_json

    body = [{ path: "surveys.#{survey.id}",
              destroy: true }]

    assert_difference 'Survey.count', -1 do
      patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)

      # should return a list of all destroyed resources
      resp = JSON.parse(response.body)
      destroyed = resp['destroyed'].map(&:symbolize_keys!)

      # the destroyed item itself should have been tracked
      assert destroyed.include?(type: 'surveys', id: survey.id, destroyed: true)

      # all destroyed associations should have been tracked
      questions.each do |q|
        assert destroyed.include?(type: 'questions',
                                  id: q['id'],
                                  destroyed: true)
      end

      # all nested destroyed associations should have been tracked
      answers.each do |a|
        assert destroyed.include?(type: 'answers', id: a['id'], destroyed: true)
      end
    end

    assert_raises ActiveRecord::RecordNotFound do
      survey.reload
    end
  end

  test 'should not create items marked for destruction' do
    user = applicants(:one)

    body = [{ path: 'surveys[1]',
              attributes: { name: 'test' },
              destroy: true }]

    assert_no_difference 'Survey.count' do
      patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)
    end
  end

  test 'changes are tracked' do
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

    body = [{ path: survey_path,
              attributes: { name: survey_name } },
            { path: "#{survey_path}.#{q1_path}.#{a1_path}",
              attributes: { value: a1_val } },
            { path: "#{survey_path}.#{q1_path}.answers[1]",
              attributes: { value: new_a_val, applicantId: user.id } },
            { destroy: true,
              path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

    # this asserts that the activity items were created but the changes were
    # not reported. this assertion checks that the change tracker respects
    # resource permissions
    assert_difference 'Activity.count', 3 do
      patch '/deep_unrest/update', auth_xhr_req({ data: body }, user)
      resp = JSON.parse(response.body).deep_symbolize_keys
      changed = resp[:changed]
      destroyed = resp[:destroyed]

      assert_equal(2, destroyed.size)
      assert_equal(3, changed.size)

      assert_equal(q2.id, destroyed[0][:id])
      assert_equal({ value: a1_val }, changed[0][:attributes])
      assert_equal({ value: new_a_val,
                     questionId: q1.id,
                     applicantId: user.id },
                   changed[1][:attributes])
      assert_equal({ name: survey_name }, changed[2][:attributes])
    end
  end

  test 'changes to indirectly affected models are tracked' do
    user = admins(:one)
    survey = surveys(:one)

    body = [{ path: "surveys.#{survey.id}",
              attributes: { approved: true } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body },
                                              user)

    resp = JSON.parse(response.body).deep_symbolize_keys
    changed = resp[:changed]

    applicant = survey.applicant

    expected_log = "Applicant #{applicant.id} updated Survey #{survey.id}"

    assert_equal(2, changed.size)
    assert_equal({ approved: true }, changed[0][:attributes])
    assert_equal({ userType: 'Applicant',
                   userId: applicant.id,
                   targetType: 'Survey',
                   targetId: survey.id,
                   logMessage: expected_log },
                 changed[1][:attributes])
  end

  test 'handles changes to nested arrays' do
    user = admins(:one)
    question = questions(:one)

    body = [{ path: "questions.#{question.id}",
              attributes: { options: [[Faker::Lorem.word, Faker::Lorem.word],
                                      [Faker::Lorem.word, Faker::Lorem.word]] } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body },
                                              user)

    resp = JSON.parse(response.body).deep_symbolize_keys
    changed = resp[:changed]

    assert_equal(1, changed.size)
    assert_equal(body[0][:attributes][:options],
                 changed[0][:attributes][:options])
  end
end
