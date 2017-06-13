module DeepUnrest
  class ApplicationController < ActionController::API
    include DeepUnrest.authentication_concern

    def context
      { current_user: current_user }
    end

    def update
      redirect = allowed_params[:redirect]
      redirect_replace = DeepUnrest.perform_update(allowed_params[:data],
                                                   current_user)
      if redirect
        response.headers.merge! update_auth_header
        redirect_to redirect_replace.call(redirect)
      else
        render json: {}, status: 200
      end
    rescue DeepUnrest::Unauthorized => err
      render json: err.message, status: 403
    rescue DeepUnrest::UnpermittedParams => err
      render json: err.message, status: 405
    rescue DeepUnrest::Conflict => err
      render json: err.message, status: 409
    end

    def current_user
      instance_eval &DeepUnrest.get_user
    end

    def allowed_params
      params.permit(:redirect,
                    data: [:destroy,
                           :path,
                           { attributes: {} }])
    end
  end
end
