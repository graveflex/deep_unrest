# frozen_string_literal: true

module DeepUnrest
  module Write
    def self.get_scope_type(item)
      return :destroy if item[:destroy]
      return :show if item[:readOnly] || item[:attributes].blank?
      return :create if item[:id] && DeepUnrest.temp_id?(item[:id].to_s)
      :update
    end

    def self.create_write_mappings(params, addr = [])
      return unless params
      params.map do |k, v|
        resource_addr = [*addr, k]
        uuid = SecureRandom.uuid
        v[:uuid] = uuid
        [{ klass: k.singularize.classify.constantize,
           policy: "#{k.singularize.classify}Policy".constantize,
           resource: "#{k.singularize.classify}Resource".constantize,
           scope_type: get_scope_type(v),
           addr: resource_addr,
           key: k.camelize(:lower),
           uuid: uuid,
           query: DeepUnrest.deep_underscore_keys(v) },
         *create_write_mappings(v[:included], [*resource_addr, :include])]
      end.flatten.compact
    end

    def self.append_ar_paths(mappings)
      mappings.each do |item|
        item[:ar_addr] = []
        item[:addr].each_with_index do |segment, i|
          next if segment == :include
          item[:ar_addr] << if item[:addr][i - 1] == :include
                              "#{segment}_attributes".to_sym
                            else
                              segment
                            end
        end
      end
    end

    def self.build_mutation_bodies(mappings)
      mappings.reject { |m| m[:scope_type] == :show }
              .each_with_object({}) do |item, memo|
        # TODO: use pkey instead of "id"
        next_attrs = item.dig(:query, :attributes || {})
                         .deep_symbolize_keys
        update_body = { id: item.dig(:query, :id),
                        **next_attrs }
        update_body[:_destroy] = true if item[:scope_type] == :destroy
        DeepUnrest.set_attr(memo, item[:ar_addr].clone, update_body)

        item[:mutate] = memo.fetch(*item[:ar_addr]) if item[:ar_addr].size == 1
      end
    end

    def self.execute_queries(mappings, context)
      ActiveRecord::Base.transaction do
        mappings.select { |m| m[:mutate] }.map do |item|
          record = case item[:scope_type]
                   when :update
                     model = item[:klass].find(item.dig(:query, :id))
                     model.assign_attributes(item[:mutate])
                     resource = item[:resource].new(model, context)
                     resource.run_callbacks :save do
                       resource.run_callbacks :update do
                         model.save
                         model
                       end
                     end
                   when :create
                     model = item[:klass].new(item[:mutate])
                     resource = item[:resource].new(model, context)
                     resource.run_callbacks :save do
                       resource.run_callbacks :create do
                         resource._model.save
                         resource._model
                       end
                     end
                   when :destroy
                     model = item[:klass].find(id)
                     resource = item[:resource].new(model, context)
                     resource.run_callbacks :remove do
                       item[:klass].destroy(id)
                     end
                   end

          result = { record: record }
          if item[:temp_id]
            result[:temp_ids] = {}
            result[:temp_ids][item[:temp_id]] = record.id
          end
          result
        end
      end
    end

    def self.write(ctx, params, user)
      temp_id_map = DeepUnrest::ApplicationController.class_variable_get(
        '@@temp_ids'
      )

      # create mappings for assembly / disassembly
      mappings = create_write_mappings(params.to_unsafe_h)

      # authorize user for requested scope(s)
      DeepUnrest.authorization_strategy.authorize(mappings, user)

      # collect authorized scopes
      # DeepUnrest.collect_authorized_scopes(mappings, user)
      append_ar_paths(mappings)

      # bulid update arguments
      build_mutation_bodies(mappings)

      # convert temp_ids from ids to non-activerecord attributes
      DeepUnrest.convert_temp_ids!(ctx[:uuid], mappings)

      # save data, run callbaks
      results = execute_queries(mappings, ctx)

      # check results for errors
      errors = results.map { |res| DeepUnrest.format_error_keys(res) }
                      .compact
                      .reject(&:empty?)
                      .compact

      if errors.empty?
        destroyed = DeepUnrest::ApplicationController.class_variable_get(
          '@@destroyed_entities'
        )
        return {
          temp_ids: temp_id_map[ctx[:uuid]],
          destroyed: destroyed
        }
      end

      # map errors to their sources
      formatted_errors = { errors: map_errors_to_param_keys(scopes, errors) }

      # raise error if there are any errors
      raise DeepUnrest::Conflict, formatted_errors.to_json
    end
  end
end
