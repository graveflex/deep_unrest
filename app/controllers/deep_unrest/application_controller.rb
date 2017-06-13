module DeepUnrest
  class ApplicationController < ActionController::API
    include DeepUnrest.authentication_concern

    def context
      { current_user: current_user }
    end


    # multipart data will be an array-like hash
    def format_data(data)
      if data.respond_to? :values
        data.values
      else
        data
      end
    end

    def update
      redirect = allowed_params[:redirect]
      data = format_data(allowed_params[:data])
      redirect_replace = DeepUnrest.perform_update(data,
                                                   current_user)
      resp = {}
      resp[:redirect] = redirect_replace.call(redirect) if redirect
      response.headers.merge! update_auth_header
      render json: resp, status: 200
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
