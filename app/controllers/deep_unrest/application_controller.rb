# frozen_string_literal: true

module DeepUnrest
  class ApplicationController < ActionController::API
    include DeepUnrest.authentication_concern

    @@temp_ids = {}
    @@destroyed_entities = []

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

    def read
      repaired_params = params[:data]
      data = repaired_params[:data]
      context = repaired_params[:context] || {}
      context[:uuid] = request.uuid
      context[:current_user] = current_user

      instance_eval &DeepUnrest.before_read if DeepUnrest.before_read

      results = DeepUnrest.perform_read(context, data, current_user)
      render json: results, status: :ok
    rescue DeepUnrest::Unauthorized => err
      render json: err.message, status: :forbidden
    rescue DeepUnrest::UnpermittedParams => err
      render json: err.message, status: :method_not_allowed
    end

    def write
      repaired_params = params[:data]
      data = repaired_params[:data]
      context = repaired_params[:context] || {}
      context[:uuid] = request.uuid
      context[:current_user] = current_user

      instance_eval &DeepUnrest.before_update if DeepUnrest.before_update

      results = DeepUnrest.perform_write(context, data, current_user)
      render json: results, status: :ok
    rescue DeepUnrest::Unauthorized => err
      render json: err.message, status: :forbidden
    rescue DeepUnrest::UnpermittedParams => err
      render json: err.message, status: :method_not_allowed
    rescue DeepUnrest::Conflict => err
      render json: err.message, status: :conflict
    ensure
      @@temp_ids.delete(request.uuid)
    end

    def update
      redirect = allowed_write_params[:data][:redirect]
      context = allowed_write_params[:data][:context] || {}
      context[:uuid] = request.uuid
      context[:current_user] = current_user
      data = repair_nested_params(allowed_write_params)[:data][:data]

      instance_eval &DeepUnrest.before_update if DeepUnrest.before_update

      results = DeepUnrest.perform_update(context, data)
      resp = { destroyed: results[:destroyed],
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
    end

    def current_user
      instance_eval &DeepUnrest.get_user
    end

    def allowed_write_params
      params.permit(data: [:redirect,
                           data: [:destroy,
                                  :path,
                                  :errorPath,
                                  { attributes: {} }]])
    end
  end
end
