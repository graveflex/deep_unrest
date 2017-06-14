module DeepUnrest
  class ApplicationController < ActionController::API
    include DeepUnrest.authentication_concern

    def context
      { current_user: current_user }
    end

    # rails can't deal with array indices in params (converts them to hashes)
    # see https://gist.github.com/bloudermilk/2884947
    def repair_nested_params(obj)
      obj.each do |key, value|
        if value.is_a?(ActionController::Parameters) || value.is_a?(Hash)
          # If any non-integer keys
          if value.keys.find { |k, _| k =~ /\D/ }
            repair_nested_params(value)
          else
            obj[key] = value.values
            value.values.each { |h| repair_nested_params(h) }
          end
        end
      end
    end

    def update
      redirect = allowed_params[:redirect]
      data = repair_nested_params(allowed_params[:data])
      redirect_replace = DeepUnrest.perform_update(data,
                                                   current_user)
      resp = {}
      resp[:redirect] = redirect_replace.call(redirect) if redirect
      render json: resp, status: 200
    rescue DeepUnrest::Unauthorized => err
      render json: err.message, status: 403
    rescue DeepUnrest::UnpermittedParams => err
      render json: err.message, status: 405
    rescue DeepUnrest::Conflict => err
      render json: err.message, status: 409
    ensure
      response.headers.merge! update_auth_header
    end

    def current_user
      instance_eval &DeepUnrest.get_user
    end

    def allowed_params
      params.permit(:redirect,
                    data: [:destroy,
                           :path,
                           :errorPath,
                           { attributes: {} }])
    end
  end
end
