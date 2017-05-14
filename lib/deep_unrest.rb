# frozen_string_literal: true

require 'deep_unrest/engine'

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

  def self.to_class(str)
    str.classify.constantize
  end

  def self.to_assoc(str)
    str.pluralize.underscore.to_sym
  end

  def self.to_update_body_key(str)
    "#{str.pluralize}Attributes".underscore.to_sym
  end

  def self.get_scope_type(id)
    case id
    when /^\[\w+\]$/
      :create
    when /^\.\w+$/
      :show
    when /^\.\*$/
      :update_all
    else
      raise InvalidId, "Unknown ID format: #{id}"
    end
  end

  # verify that this is an actual association of the parent class.
  def self.add_parent_scope(parent, type)
    reflection = parent[:klass].reflect_on_association(to_assoc(type))
    raise NoMethodError unless reflection.klass == to_class(type)
    unless parent[:id]
      raise InvalidParentScope, 'Unable to update associations of collections '\
                                "('#{parent[:type]}.#{type}')."
    end
    { base: parent[:scope], method: reflection.name }
  rescue NoMethodError
    raise InvalidAssociation, "'#{parent[:type]}' has no association '#{type}'"
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
    when :update_all
      add_parent_scope(memo[memo.size - 1], type)
    when :all
      { base: to_class(type), method: :all }
    end
  end

  def self.parse_path(path)
    rx = /(?<type>\w+)(?<id>(?:\[|\.)[\w+\*\]]+)/
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

  def self.collect_action_scopes(operation)
    resources = parse_path(operation[:path])
    resources.each_with_object([]) do |(type, id), memo|
      validate_association(memo.last, type)
      action = memo.size == resources.size - 1 ? operation[:action].to_sym : nil
      scope_type = action || get_scope_type(id)
      scope = get_scope(scope_type, memo, type, id)
      context = { type: type,
                  action: action,
                  scope_type: scope_type,
                  scope: scope,
                  klass: to_class(type),
                  id: id }

      context[:path] = operation[:path] unless scope_type == :show
      memo.push(context)
    end
  end

  def self.collect_all_scopes(params)
    idx = {}
    params.map { |operation| collect_action_scopes(operation) }
          .flatten
          .uniq
          .map do |op|
            unless op[:scope_type] == :show
              op[:index] = update_indices(idx, op[:type])[op[:type]] - 1
            end
            op
          end
  end

  def self.parse_id(id_str)
    id_match = id_str.match(/^\.(?<id>\d+)$/)
    id_match && id_match[:id]
  end

  def self.set_action(cursor, operation)
    case operation[:action].to_sym
    when :destroy
      cursor[:_destroy] = true
    when :update, :create
      cursor.merge! operation[:attributes]
    end
    cursor
  end

  def self.get_mutation_cursor(memo, cursor, addr, type, id)
    # TODO: here - determine source (Model) + call (update / update_all)
    if memo
      cursor[addr] = [{}]
      next_cursor = cursor[addr][0]
    else
      cursor = {}
      type_sym = type.to_sym
      method = id ? :update : :update_all
      cursor[type_sym] = {
        klass: to_class(type)
      }
      cursor[type_sym][:operations] = {}
      cursor[type_sym][:operations][id] = {}
      cursor[type_sym][:operations][id][method] = {
        method: method,
        body: {
          id: id
        }
      }
      memo = cursor
      next_cursor = cursor[type_sym][:operations][id][method][:body]
    end
    [memo, next_cursor]
  end

  def self.build_mutation_fragment(op, rest = nil, memo = nil, cursor = nil)
    rest ||= parse_path(op[:path])

    if rest.empty?
      set_action(cursor, op)
      return memo
    end

    type, id_str = rest.shift
    addr = to_update_body_key(type)
    id = parse_id(id_str)

    memo, next_cursor = get_mutation_cursor(memo, cursor, addr, type, id)

    next_cursor[:id] = id
    build_mutation_fragment(op, rest, memo, next_cursor)
  end

  def self.build_mutation_body(ops)
    ops.each_with_object({}) do |op, memo|
      memo.deeper_merge(build_mutation_fragment(op))
    end
  end

  def self.mutate(mutation)
    mutation.map do |_, item|
      item[:operations].map do |id, ops|
        ops.map do |op_name, action|
          case action[:method]
          when :update
            item[:klass].update(id, action[:body])
          when :create
            item[:klass].create(action[:body])
          end
        end
      end
    end
  end

  def self.parse_error_path(key)
    rx = /(((^|\.)(?<type>[^\.\[]+)(?:\[(?<idx>\d+)\])\.)?(?<field>[\w\.]+)$)/
    rx.match(key)
  end

  def self.format_errors(operation, path_info, values)
    if operation
      return values.map do |msg|
        { title: "#{path_info[:field].humanize} #{msg}",
          detail: msg,
          source: { pointer: "#{operation[:path]}.#{path_info[:field]}" } }
      end
    end
    values.map do |msg|
      { title: msg, detail: msg, source: { pointer: nil } }
    end
  end

  def self.map_errors_to_param_keys(scopes, errors)
    errors.map do |err|
      err.messages.map do |key, values|
        path_info = parse_error_path(key)
        operation = scopes.find do |s|
          s[:type] == path_info[:type] && s[:index] == path_info[:idx].to_i
        end

        format_errors(operation, path_info, values)
      end
    end.flatten
  end

  def self.perform_update(params, user)
    # identify requested scope(s)
    scopes = collect_all_scopes(params)

    # authorize user for requested scope(s)
    DeepUnrest.authorization_strategy.authorize(scopes, user).flatten

    # should have a map like:
    # { [type]: { [action]: { [id]: entity } }
    # { [type]: { [action]: { [scope]: collection } }

    # collect mutations
    mutations = build_mutation_body(params)

    results = mutate(mutations).flatten

    errors = results.map(&:errors).compact

    unless errors.empty?
      formatted_errors = map_errors_to_param_keys(scopes, errors)
      return { status: 409,
               errors: formatted_errors }
    end

    { status: 200,
      data: format_results(scopes) }

    # perform transaction
    # if success:
    #   redirect to endpont
    # else
    #   build errors
    #   return errors
  end
end
