require 'test_helper'

class UpdateTest < ActionDispatch::IntegrationTest
  test "authorization is performed when making updates" do
    user = applicants(:confirmed_email_applicant)
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

    body = [{ action: 'update',
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

    expected_error = "Applicant with id '#{user.id}' is not authorized to "\
                     "update Survey with id '#{survey.id}'"

    err = assert_raises Pundit::NotAuthorizedError do
      patch '/update', auth_xhr_req({ data: body }, user)
    end
    assert_equal expected_error, err.message
  end

  test 'users can update deeply nested resources that they have access to' do
    user = applicants(:confirmed_email_applicant)
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

    body = [{ action: 'update',
              path: "#{survey_path}.#{q1_path}.#{a1_path}",
              attributes: { value: a1_val } },
            { action: 'create',
              path: "#{survey_path}.#{q1_path}.answers[1]",
              attributes: { value: new_a_val,
                            applicant_id: user.id,
                            survey_id: survey.id,
                            question_id: q1.id } },
            { action: 'destroy',
              path: "#{survey_path}.#{q2_path}.#{a2_path}" }]

    patch '/update', auth_xhr_req({ data: body }, user)

    # existing record was updated
    a1.reload
    assert_equal a1_val, a1.value

    # existing record was removed
    assert_raises ActiveRecord::RecordNotFound do
      a2.reload
    end

    # new record was created
    assert_equal Answer.last.value, new_a_val
  end

  test 'validation errors are labeled with the correct path' do
    user = applicants(:confirmed_email_applicant)
    survey = surveys(:one)
    survey_path = "surveys.#{survey.id}"
    q1 = questions(:one)
    q1_path = "questions.#{q1.id}"
    a1_val = "XXXXX#{Faker::TwinPeaks.quote}"
    a2_val = "XXXXX#{Faker::TwinPeaks.quote}"

    body = [{ action: 'create',
              path: "#{survey_path}.#{q1_path}.answers[1]",
              attributes: { survey_id: survey.id,
                            value: a1_val,
                            applicant_id: user.id,
                            question_id: q1.id } },
            { action: 'create',
              path: "#{survey_path}.#{q1_path}.answers[2]",
              attributes: { survey_id: survey.id,
                            value: Faker::TwinPeaks.quote,
                            applicant_id: user.id,
                            question_id: q1.id } },
            { action: 'create',
              path: "#{survey_path}.#{q1_path}.answers[3]",
              attributes: { survey_id: survey.id,
                            value: a2_val,
                            applicant_id: user.id,
                            question_id: q1.id } }]

    patch '/update', auth_xhr_req({ data: body }, user)

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
end
