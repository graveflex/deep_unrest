# frozen_string_literal: true

module DeepUnrest
  class ApplicationController < ActionController::API
    include DeepUnrest.authentication_concern

    around_action :allow_nested_arrays, only: :update

    @@temp_ids = {}
    @@destroyed_entities = []
    @@changed_entities = []

    def context
      { current_user: current_user }
    end

    # rails can't deal with array indices in params (converts them to hashes)
    # see https://gist.github.com/bloudermilk/2884947
    def repair_nested_params(obj)
      return unless obj.respond_to?(:each)
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
      redirect = allowed_params[:data][:redirect]
      data = repair_nested_params(allowed_params)[:data][:data]
      results = DeepUnrest.perform_update(request.uuid, data, current_user)
      resp = { destroyed: results[:destroyed],
               changed: results[:changed],
               tempIds: results[:temp_ids] }
      resp[:redirect] = results[:redirect_regex].call(redirect) if redirect
      render json: resp, status: :ok
    rescue DeepUnrest::Unauthorized => err
      render json: err.message, status: :forbidden
    rescue DeepUnrest::UnpermittedParams => err
      render json: err.message, status: :method_not_allowed
    rescue DeepUnrest::Conflict => err
      render json: err.message, status: :conflict
    ensure
      @@temp_ids.delete(request.uuid)
      @@destroyed_entities.clear
      @@changed_entities.clear
    end

    def current_user
      instance_eval &DeepUnrest.get_user
    end

    def allowed_params
      params.permit(data: [:redirect,
                           data: [:destroy,
                                  :path,
                                  :errorPath,
                                  { attributes: {} }]])
    end

    def allow_nested_arrays
      ::ActionController::Parameters::PERMITTED_SCALAR_TYPES << Array
      yield
      ::ActionController::Parameters::PERMITTED_SCALAR_TYPES - [Array]
    end
  end
end
