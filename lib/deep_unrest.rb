# frozen_string_literal: true

require 'deep_unrest/engine'

# workaronud for rails bug with association indices.
# see https://github.com/rails/rails/pull/24728
module ActiveRecord
  # monkey-patch
  module AutosaveAssociation
    # Returns the record for an association collection that should be validated
    # or saved. If +autosave+ is +false+ only new records will be returned,
    # unless the parent is/was a new record itself.
    def associated_records_to_validate_or_save(association,
                                               new_record,
                                               autosave)
      if new_record || autosave
        association && association.target
      else
        association.target.find_all(&:new_record?)
      end
    end
  end
end

# Update deeply nested associations wholesale
module DeepUnrest
  class InvalidParentScope < ::StandardError
  end

  class InvalidAssociation < ::StandardError
  end

  class InvalidPath < ::StandardError
  end

  class ValidationError < ::StandardError
  end

  class InvalidId < ::StandardError
  end

  class UnpermittedParams < ::StandardError
  end

  class Conflict < ::StandardError
  end

  class Unauthorized < ::StandardError
  end

  def self.to_class(str)
    str.classify.constantize
  end

  def self.to_assoc(str)
    str.underscore.to_sym
  end

  def self.to_update_body_key(str)
    "#{str}Attributes".underscore.to_sym
  end

  def self.get_resource(type)
    "#{type.classify}Resource".constantize
  end

  def self.get_scope_type(id, last, destroy)
    case id
    when /^\[[\w+\-]+\]$/
      :create
    when /^\.\w+$/
      if last
        if destroy.present?
          :destroy
        else
          :update
        end
      else
        :show
      end
    when /^\.\*$/
      if last
        if destroy.present?
          :destroy_all
        else
          :update_all
        end
      else
        :index
      end
    else
      raise InvalidId, "Unknown ID format: #{id}"
    end
  end

  def self.temp_id?(str)
    /\[[\w+\-]+\]$/.match(str)
  end

  def self.plural?(s)
    str = s.to_s
    str.pluralize == str && str.singularize != str
  end

  # verify that this is an actual association of the parent class.
  def self.add_parent_scope(parent, type)
    reflection = parent[:klass].reflect_on_association(to_assoc(type))
    { base: parent[:scope], method: reflection.name }
  end

  def self.validate_association(parent, type)
    return unless parent
    reflection = parent[:klass].reflect_on_association(to_assoc(type))
    raise NoMethodError unless reflection.klass == to_class(type)
    unless parent[:id]
      raise InvalidParentScope, 'Unable to update associations of collections '\
                                "('#{parent[:type]}.#{type}')."
    end
  rescue NoMethodError
    raise InvalidAssociation, "'#{parent[:type]}' has no association '#{type}'"
  end

  def self.get_scope(scope_type, memo, type, id_str = nil)
    case scope_type
    when :show, :update, :destroy
      id = /^\.(?<id>\d+)$/.match(id_str)[:id]
      { base: to_class(type), method: :find, arguments: [id] }
    when :update_all, :index
      if memo.empty?
        { base: to_class(type), method: :all }
      else
        add_parent_scope(memo[memo.size - 1], type)
      end
    when :all
      { base: to_class(type), method: :all }
    end
  end

  def self.parse_path(path)
    rx = /(?<type>\w+)(?<id>(?:\[|\.)[\w+\-\*\]]+)/
    result = path.scan(rx)
    unless result.map { |res| res.join('') }.join('.') == path
      raise InvalidPath, "Invalid path: #{path}"
    end
    result
  end

  def self.update_indices(indices, type)
    indices[type] ||= 0
    indices[type] += 1
    indices
  end

  def self.parse_attributes(type, scope_type, attributes, user)
    p = JSONAPI::RequestParser.new
    resource = get_resource(type)
    p.resource_klass = resource
    ctx = { current_user: user }
    opts = if scope_type == :create
             resource.creatable_fields(ctx)
           else
             resource.updatable_fields(ctx)
           end

    p.parse_params({ attributes: attributes }, opts)[:attributes]
  rescue JSONAPI::Exceptions::ParametersNotAllowed
    unpermitted_keys = attributes.keys.map(&:to_sym) - opts
    msg = "Attributes #{unpermitted_keys} of #{type.classify} not allowed"
    msg += " to #{user.class} with id '#{user.id}'" if user
    raise UnpermittedParams, [{ title: msg }].to_json
  end

  def self.collect_action_scopes(operation)
    resources = parse_path(operation[:path])
    resources.each_with_object([]) do |(type, id), memo|
      validate_association(memo.last, type)
      scope_type = get_scope_type(id,
                                  memo.size == resources.size - 1,
                                  operation[:destroy])
      scope = get_scope(scope_type, memo, type, id)
      context = { type: type,
                  scope_type: scope_type,
                  scope: scope,
                  klass: to_class(type),
                  error_path: operation[:errorPath],
                  id: id }

      context[:path] = operation[:path] unless scope_type == :show
      memo.push(context)
    end
  end

  def self.collect_all_scopes(params)
    idx = {}
    params.map { |operation| collect_action_scopes(operation) }
          .flatten
          .each_with_object({}) do |op, memo|
            # ensure no duplicate scopes
            memo["#{op[:scope_type]}-#{op[:type]}-#{op[:id]}"] ||= {}
            memo["#{op[:scope_type]}-#{op[:type]}-#{op[:id]}"].merge!(op)
          end.values
          .map do |op|
            unless op[:scope_type] == :show
              op[:index] = update_indices(idx, op[:type])[op[:type]] - 1
            end
            op
          end
  end

  def self.parse_id(id_str)
    return false if id_str.nil?
    id_match = id_str.match(/^\.?(?<id>\d+)$/)
    id_match && id_match[:id]
  end

  def self.increment_error_indices(path_info, memo)
    path_info.each_with_index.map do |(type, id), i|
      next if i.zero?
      parent_type, parent_id = path_info[i - 1]
      key = "#{parent_type}#{parent_id}#{type}"
      memo[key] = [] unless memo[key]
      idx = memo[key].find_index(id)
      unless idx
        idx = memo[key].size
        memo[key] << id
      end

      "#{type.underscore}[#{idx}]"
    end.compact.join('.')
  end

  def self.set_action(cursor, operation, type, user, scopes, err_path_memo)
    # TODO: this is horrible. find a better way to go about this
    path_info = parse_path(operation[:path])
    id_str = path_info.last[1]
    id = parse_id(id_str)
    action = get_scope_type(id_str,
                            true,
                            operation[:destroy])

    cursor[:id] = id || id_str

    scope = scopes.find do |s|
      s[:type] == type && s[:id] == id_str
    end

    scope[:ar_error_key] = increment_error_indices(path_info, err_path_memo)
    scope[:dr_error_key] = path_info.map { |pair| pair.join('') }.join('.')

    case action
    when :destroy
      cursor[:_destroy] = true
      scope[:destroyed] = true
    when :update, :create, :update_all
      cursor.merge! parse_attributes(type,
                                     operation[:action],
                                     operation[:attributes],
                                     user)
    end

    cursor
  end

  def self.get_mutation_cursor(memo, cursor, addr, type, id, temp_id, scope_type)
    if memo
      record = { id: id || temp_id }
      if plural?(type)
        cursor[addr] = [record]
        next_cursor = cursor[addr][0]
      else
        cursor[addr] = record
        next_cursor = cursor[addr]
      end
    else
      method = scope_type == :show ? :update : scope_type
      cursor = {}
      type_sym = type.to_sym
      klass = to_class(type)
      body = {}
      body[klass.primary_key.to_sym] = id if id
      cursor[type_sym] = {
        klass: klass,
        resource: get_resource(type)
      }
      cursor[type_sym][:operations] = {}
      cursor[type_sym][:operations][id || temp_id] = {}
      cursor[type_sym][:operations][id || temp_id][method] = {
        method: method,
        body: body
      }
      cursor[type_sym][:operations][id || temp_id][method][:temp_id] = temp_id if temp_id
      memo = cursor
      next_cursor = cursor[type_sym][:operations][id || temp_id][method][:body]
    end
    [memo, next_cursor]
  end

  def self.convert_temp_ids!(ctx, mutations)
    case mutations
    when Hash
      mutations.keys.map do |key|
        val = mutations[key]
        if ['id', :id].include?(key)
          unless parse_id(val)
            mutations.delete(key)
            mutations[:deep_unrest_temp_id] = val
            mutations[:deep_unrest_context] = ctx
          end
        else
          convert_temp_ids!(ctx, val)
        end
      end
    when Array
      mutations.map { |val| convert_temp_ids!(ctx, val) }
    end
    mutations
  end

  def self.build_mutation_fragment(op, scopes, user, err_path_memo, rest = nil, memo = nil, cursor = nil, type = nil)
    rest ||= parse_path(op[:path])

    if rest.empty?
      set_action(cursor, op, type, user, scopes, err_path_memo)
      return memo
    end

    type, id_str = rest.shift
    addr = to_update_body_key(type)
    id = parse_id(id_str)
    scope_type = get_scope_type(id_str, rest.blank?, op[:destroy])
    temp_id = scope_type == :create ? id_str : nil

    memo, next_cursor = get_mutation_cursor(memo,
                                            cursor,
                                            addr,
                                            type,
                                            id,
                                            temp_id,
                                            scope_type)

    next_cursor[:id] = id if id
    build_mutation_fragment(op, scopes, user, err_path_memo, rest, memo, next_cursor, type)
  end

  def self.combine_arrays(a, b)
    # get list of items duped by id
    groups = (a + b).flatten.group_by { |item| item[:id] }
    dupes = groups.select { |_, v| v.size > 1 }.values

    # filter non-dupe
    non_dupes = groups.select { |_, v| v.size == 1 }.values

    # recrsively merge dupes
    merged = dupes.map do |(a2, b2)|
      a2.deep_merge(b2) do |_, a3, b3|
        if a3.is_a? Array
          combine_arrays(a3, b3)
        else
          b3
        end
      end
    end

    # add merged dupes to non-dupes
    (non_dupes + merged).flatten
  end

  def self.build_mutation_body(ops, scopes, user)
    err_path_memo = {}
    ops.each_with_object(HashWithIndifferentAccess.new({})) do |op, memo|
      memo.deep_merge!(build_mutation_fragment(op, scopes, user, err_path_memo)) do |key, a, b|
        if a.is_a? Array
          combine_arrays(a, b)
        else
          b
        end
      end
    end
  end

  def self.mutate(mutation, user)
    ActiveRecord::Base.transaction do
      mutation.map do |_, item|
        item[:operations].map do |id, ops|
          ops.map do |_, action|
            record = case action[:method]
                     when :update_all
                       DeepUnrest.authorization_strategy
                                 .get_authorized_scope(user, item[:klass])
                                 .update(action[:body])
                       nil
                     when :destroy_all
                       DeepUnrest.authorization_strategy
                                 .get_authorized_scope(user, item[:klass])
                                 .destroy_all
                       nil
                     when :update
                       model = item[:klass].find(id)
                       model.assign_attributes(action[:body])
                       resource = item[:resource].new(model, current_user: user)
                       resource.run_callbacks :save do
                         resource.run_callbacks :update do
                           model.save
                           model
                         end
                       end
                     when :create
                       model = item[:klass].new(action[:body])
                       resource = item[:resource].new(model, current_user: user)
                       resource.run_callbacks :save do
                         resource.run_callbacks :create do
                           item[:klass].create(action[:body])
                         end
                       end
                     when :destroy
                       model = item[:klass].find(id)
                       resource = item[:resource].new(model, current_user: user)
                       resource.run_callbacks :remove do
                         item[:klass].destroy(id)
                       end
                     end

            result = { record: record }
            if action[:temp_id]
              result[:temp_ids] = {}
              result[:temp_ids][action[:temp_id]] = record.id
            end
            result
          end
        end
      end
    end
  end

  def self.parse_error_path(key)
    rx = /^(?<path>.*\])?\.?(?<field>[\w\-\.]+)$/
    rx.match(key)
  end

  # handle error titles in cases where error value is an array
  def self.format_error_title(title)
    if title.is_a?(Array)
      title.join(', ')
    else
      title
    end
  end

  def self.format_errors(operation, path_info, values)
    if operation
      return values.map do |msg|
        base_path = (
          operation[:error_path] ||
          operation[:dr_error_key] ||
          operation[:ar_error_key]
        )
        # TODO: case field name according to jsonapi_resources settings
        field_name = path_info[:field].camelize(:lower)
        pointer = [base_path, field_name].compact.join('.')
        active_record_path = [operation[:ar_error_key],
                              field_name].reject(&:empty?).compact.join('.')
        deep_unrest_path = [operation[:dr_error_key],
                            field_name].compact.join('.')
        { title: "#{path_info[:field].humanize} #{format_error_title(msg)}",
          detail: msg,
          source: { pointer: pointer,
                    deepUnrestPath: deep_unrest_path,
                    activeRecordPath: active_record_path } }
      end
    end
    values.map do |msg|
      { title: msg, detail: msg, source: { pointer: nil } }
    end
  end

  def self.map_errors_to_param_keys(scopes, ops)
    ops.map do |errors|
      errors.map do |key, values|
        path_info = parse_error_path(key.to_s)
        operation = scopes.find do |s|
          (
            s[:ar_error_key] &&
            s[:ar_error_key] == (path_info[:path] || '') &&
            s[:scope_type] != :show
          )
        end
        format_errors(operation, path_info, values)
      end
    end.flatten
  end

  def self.build_redirect_regex(replacements)
    replacements ||= []

    replace_ops = replacements.map do |k, v|
      proc { |str| str.sub(k.to_s, v.to_s) }
    end

    proc do |str|
      replace_ops.each { |op| str = op.call(str) }
      str
    end
  end

  def self.format_error_keys(res)
    record = res[:record]
    record&.errors&.messages
  end

  def self.perform_update(ctx, params, user)
    temp_id_map = DeepUnrest::ApplicationController.class_variable_get(
      '@@temp_ids'
    )

    temp_id_map[ctx] ||= {}

    # reject new resources marked for destruction
    viable_params = params.reject do |param|
      temp_id?(param[:path]) && param[:destroy].present?
    end

    # identify requested scope(s)
    scopes = collect_all_scopes(viable_params)

    # authorize user for requested scope(s)
    DeepUnrest.authorization_strategy.authorize(scopes, user).flatten

    # bulid update arguments
    mutations = build_mutation_body(viable_params, scopes, user)

    # convert temp_ids from ids to non-activerecord attributes
    convert_temp_ids!(ctx, mutations)

    # perform update
    results = mutate(mutations, user).flatten

    # check results for errors
    errors = results.map { |res| format_error_keys(res) }
                    .compact
                    .reject(&:empty?)
                    .compact

    if errors.empty?
      return {
        redirect_regex: build_redirect_regex(temp_id_map[ctx]),
        temp_ids: temp_id_map[ctx],
        destroyed: scopes.select { |item| item[:destroyed] }
                         .map do |item|
                           { type: item[:type],
                             id: parse_id(item[:id]),
                             destroyed: true }
                         end
      }
    end

    # map errors to their sources
    formatted_errors = { errors: map_errors_to_param_keys(scopes, errors) }

    # raise error if there are any errors
    raise Conflict, formatted_errors.to_json unless formatted_errors.empty?
  end
end
