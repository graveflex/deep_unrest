class ApplicationController < ActionController::Base
  include DeviseTokenAuth::Concerns::SetUserByToken
  protect_from_forgery with: :null_session

  def update
    resp = DeepUnrest.perform_update(allowed_params[:data], current_applicant)
    if resp[:errors]
      render json: { errors: resp[:errors] }, status: resp[:status]
    else
      render json: { data: resp[:data] }, status: resp[:status]
    end
  end

  def allowed_params
    params.permit(data: [:action,
                         :path,
                         { attributes: {} }])
  end
end
