require 'test_helper'

class UpdateTest < ActionDispatch::IntegrationTest
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

    assert_response :redirect
    follow_redirect!

    assert_response :success
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

    body = [{ path: "#{survey_path}.#{q1_path}.answers[1]",
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
                                             '.answers[1].value' } },
                        { title: 'Value is invalid',
                          detail: 'is invalid',
                          source: { pointer: "surveys.#{survey.id}"\
                                                      ".questions.#{q1.id}"\
                                                      '.answers[3].value' } }]

    errors = JSON.parse(response.body)['errors'].map do |e|
      ActiveSupport::HashWithIndifferentAccess.new(e).deep_symbolize_keys
    end

    assert_response 409
    assert_equal expected_results, errors
  end

  test 'replaces temp_ids in redirects with new actual ids' do
    user = applicants(:one)

    body = [{ path: 'surveys[1]',
              attributes: { name: Faker::TwinPeaks.quote,
                            applicantId: user.id } }]

    patch '/deep_unrest/update', auth_xhr_req({ data: body,
                                                redirect: '/surveys/[1]' },
                                              user)

    survey = Survey.last

    assert_response :redirect
    assert_redirected_to "/surveys/#{survey.id}"
  end
end
