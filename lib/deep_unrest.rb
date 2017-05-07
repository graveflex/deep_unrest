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
      raise InvalidParentScope, "cannot find association '#{type}' of "\
                                "collection '#{parent[:type]}'"
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

  def collect_action_scopes(operation)
    parse_path(operation[:path]).each_with_object([]) do |(type, id), memo|
      action = memo.size == resources.size - 1 ? operation[:action] : nil
      scope_type = action || get_scope_type(id, memo.size)
      scope = get_scope(scope_type, memo, type, id)
      memo << { type: type, action: action, scope_type: scope_type,
                scope: scope, klass: to_class(type), id: id }
    end
  end

  # def collect_all_scopes(params)
  #   scopes = params.map { |operation| collect_action_scopes(operation) }
  #   scopes.reduce ({}) do |memo, scope|
  #     scopes
  #   end
  # end

  def perform_update(params)
    # identify requested scope(s)
    # authorize user for requested scope(s)
    # build update objects
    # perform transaction
    # if success:
    #   redirect to endpont
    # else
    #   build errors
    #   return errors
  end
end
