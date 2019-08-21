# frozen_string_literal: true

module DeepUnrest
  module Write
    def self.get_scope_type(item)
      return :destroy if item[:destroy]
      return :show if item[:readOnly] || item[:attributes].blank?
      return :create if item[:id] && DeepUnrest.temp_id?(item[:id].to_s)

      :update
    end

    def self.create_write_mapping(k, v, addr, idx = nil)
      path = k
      path += '[]' if idx
      resource_addr = [*addr, path]
      resource_addr << idx if idx
      uuid = SecureRandom.uuid
      v[:uuid] = uuid
      [{ klass: k.singularize.classify.constantize,
         policy: "#{k.singularize.classify}Policy".constantize,
         resource: "#{k.singularize.classify}Resource".constantize,
         scope_type: get_scope_type(v),
         addr: resource_addr,
         key: k.camelize(:lower),
         uuid: uuid,
         query: v },
       *create_write_mappings(v[:include], [*resource_addr, :include])]
    end

    def self.create_mapping_sequence(k, v, addr)
      v.each_with_index.map do |item, idx|
        create_write_mapping(k, item, addr, idx)
      end
    end

    def self.create_write_mappings(params, addr = [])
      return unless params

      params.map do |k, v|
        if v.is_a? Array
          create_mapping_sequence(k, v, addr)
        else
          create_write_mapping(k, v, addr)
        end
      end.flatten.compact
    end

    def self.append_ar_paths(mappings)
      mappings.each do |item|
        item[:ar_addr] = []
        addr = [*item[:addr]]
        until addr.empty?
          segment = addr.shift
          item[:ar_addr] << segment if item[:ar_addr].empty?
          next unless segment == :include

          next_segment = "#{addr.shift.gsub('[]', '')}_attributes"
          idx = addr.shift if addr[0].is_a? Integer
          next_segment += '[]' if idx
          item[:ar_addr] << next_segment
          item[:ar_addr] << idx if idx
        end
      end
    end

    def self.authorize_attributes(mappings, ctx)
      unauthorized_items = []

      mappings.reject { |m| m[:scope_type] == :show }
              .reject { |m| m[:destroy] }
              .each do |item|
        attributes = item.dig(:query, :attributes) || {}
        resource = item[:resource]
        p = JSONAPI::RequestParser.new
        p.resource_klass = resource
        opts = if item[:scope_type] == :create
                 resource.creatable_fields(ctx)
               else
                 resource.updatable_fields(ctx)
               end

        p.parse_params({ attributes: attributes }, opts)[:attributes]
      rescue JSONAPI::Exceptions::ParameterNotAllowed
        unpermitted_keys = attributes.keys.map(&:to_sym) - opts
        item[:errors] = unpermitted_keys.each_with_object({}) do |attr_key, memo|
          memo[attr_key] = 'Unpermitted parameter'
        end
        unauthorized_items << item
      end

      return if unauthorized_items.blank?

      msg = serialize_errors(unauthorized_items)
      raise DeepUnrest::UnpermittedParams, msg
    end

    def self.build_mutation_bodies(mappings)
      mappings.each_with_object({}) do |item, memo|
        # TODO: use pkey instead of "id"
        next_attrs = (item.dig(:query, :attributes) || {})
                     .deep_symbolize_keys
        update_body = { id: item.dig(:query, :id),
                        deep_unrest_query_uuid: item.dig(:query, :uuid),
                        **DeepUnrest.deep_underscore_keys(next_attrs) }
        update_body[:_destroy] = true if item[:scope_type] == :destroy
        DeepUnrest.set_attr(memo, item[:ar_addr].clone, update_body)
        if item[:ar_addr].size == 1
          item[:mutate] = memo.fetch(*item[:ar_addr])
          item[:scope_type] = :update if item[:scope_type] == :show
        end
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

          item[:record] = record
          result = { record: record }
          if item[:temp_id]
            result[:temp_ids] = {}
            result[:temp_ids][item[:temp_id]] = record.id
          end
          result
        end
      end
    end

    def self.serialize_changes(ctx, mappings, changed)
      changed.select { |c| c[:query_uuid] }
             .each_with_object({}) do |c, memo|
               mapping = mappings.find { |m| m.dig(:query, :uuid) == c[:query_uuid] }
               mapping[:query][:fields] = c[:attributes].keys
               mapping[:record] = c[:klass].new(id: c[:id])
               mapping[:record].assign_attributes(c[:attributes])
               result = DeepUnrest.serialize_result(ctx, mapping)
               DeepUnrest.set_attr(memo, mapping[:addr], result)
             end
    end

    def self.addr_to_lodash_path(path_arr)
      lodash_path = []
      until path_arr.empty?
        segment = path_arr.shift
        if segment.match(/\[\]$/)
          idx = path_arr.shift
          segment = "#{segment.gsub('[]', '')}[#{idx}]"
        end
        lodash_path << segment
      end
      lodash_path.join('.')
    end

    def self.serialize_destroyed(_ctx, mappings, destroyed)
      destroyed.select { |d| d[:query_uuid] }
               .map do |d|
        mapping = mappings.find { |m| m.dig(:query, :uuid) == d[:query_uuid] }
        lodash_path = addr_to_lodash_path(mapping[:addr])
        { id: d[:id], path: lodash_path, type: mapping[:key].pluralize }
      end
    end

    def self.serialize_errors(mappings)
      { errors: mappings.each_with_object({}) do |item, memo|
        err = {
          id: item.dig(:query, :id),
          type: item.dig(:query, :type),
          attributes: item[:errors,]
        }
        DeepUnrest.set_attr(memo, [*item[:addr]], err)
      end }.to_json
    end

    def self.format_ar_error_path(base, ar_path)
      path_arr = ar_path.gsub(/\.(?!\w+$)/, '.included.')
                        .gsub(/\.(?=\w+$)/, '.attributes.\1')
                        .gsub(/\[(\d+)\]/, '[].\1')
                        .split('.')

      if path_arr.size == 1
        path_arr.unshift('attributes')
      elsif path_arr.size > 1
        path_arr.unshift('included')
      end

      [*base, *path_arr]
    end

    def self.map_ar_errors_to_param_keys(mappings)
      mappings
        .each_with_object({}) do |item, memo|
          item[:record]&.errors&.messages&.each do |ar_path, msg|
            err_path = format_ar_error_path(item[:addr], ar_path.to_s)
            DeepUnrest.set_attr(memo, err_path, msg)
          end
        end
    end

    def self.write(ctx, params, user)
      temp_id_map = DeepUnrest::ApplicationController.class_variable_get(
        '@@temp_ids'
      )
      temp_id_map[ctx[:uuid]] ||= {}

      # create mappings for assembly / disassembly
      mappings = create_write_mappings(params.to_unsafe_h)

      # authorize user for requested scope(s)
      DeepUnrest.authorization_strategy.authorize(mappings, user)

      authorize_attributes(mappings, ctx)

      # collect authorized scopes
      # DeepUnrest.collect_authorized_scopes(mappings, user)
      append_ar_paths(mappings)

      # bulid update arguments
      build_mutation_bodies(mappings)

      # convert temp_ids from ids to non-activerecord attributes
      DeepUnrest.convert_temp_ids!(ctx[:uuid], mappings.select { |m| m[:mutate] })

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

        changed = DeepUnrest::ApplicationController.class_variable_get(
          '@@changed_entities'
        )

        return {
          temp_ids: temp_id_map[ctx[:uuid]],
          destroyed: serialize_destroyed(ctx, mappings, destroyed),
          changed: serialize_changes(ctx, mappings, changed)
        }
      end

      # map errors to their sources
      formatted_errors = { errors: map_ar_errors_to_param_keys(mappings) }

      # raise error if there are any errors
      raise DeepUnrest::Conflict, formatted_errors.to_json
    end
  end
end
