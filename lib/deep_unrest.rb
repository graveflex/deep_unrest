# frozen_string_literal: true

require 'deep_unrest/engine'

# Update deeply nested associations wholesale
module DeepUnrest
  class InvalidParentScope < ::StandardError
  end

  class InvalidAssociation < ::StandardError
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

  def self.get_scope_type(id, i = nil)
    case id
    when /^\[\d+\]$/
      :create
    when /^\.\d+$/
      :show
    else i && i.positive? ? :related : :all
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

  def self.get_scope(scope_type, memo, type, id_str = nil)
    case scope_type
    when :show, :update, :destroy
      id = /^\.(?<id>\d+)$/.match(id_str)[:id]
      { base: to_class(type), method: :find, arguments: [id] }
    when :related
      add_parent_scope(memo[memo.size - 1], type)
    when :all
      { base: to_class(type), method: :all }
    end
  end

  def self.parse_path(path)
    rx = /(?:^|\.)(?<type>[^\s\.\[]+(?:$)?)(?<id>(?:\.|\[)\d+(?:\])?)?/
    path.scan(rx)
  end

  def self.collect_action_scopes(operation)
    resources = parse_path(operation[:path])
    resources.each_with_object([]) do |(type, id), memo|
      action = memo.size == resources.size - 1 ? operation[:action].to_sym : nil
      scope_type = action || get_scope_type(id, memo.size)
      scope = get_scope(scope_type, memo, type, id)
      memo << { type: type, action: action, scope_type: scope_type,
                scope: scope, klass: to_class(type), id: id }
    end
  end

  def self.collect_all_scopes(params)
    params.map { |operation| collect_action_scopes(operation) }.flatten.uniq
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
      cursor[type_sym][id] = {}
      cursor[type_sym][id][method] = {
        method: method,
        body: {
          id: id
        }
      }
      memo = cursor
      next_cursor = cursor[type_sym][id][method][:body]
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

  def self.build_mutation_body(params)
    params.each_with_object({}) do |op, memo|
      memo.deeper_merge(build_mutation_fragment(op))
    end
  end

  def perform_update(params)
    # identify requested scope(s)
    scopes = collect_all_scopes(params)

    # authorize user for requested scope(s)
    # TODO

    # collect mutations
    mutations = build_mutation_body(params)

    # perform transaction
    # if success:
    #   redirect to endpont
    # else
    #   build errors
    #   return errors
  end
end
