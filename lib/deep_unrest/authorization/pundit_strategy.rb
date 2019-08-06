# frozen_string_literal: true

module DeepUnrest
  module Authorization
    class PunditStrategy < DeepUnrest::Authorization::BaseStrategy
      def self.get_policy_name(method)
        "#{method}?".to_sym
      end

      def self.get_policy(klass)
        "#{klass}Policy".constantize
      end

      def self.get_authorized_scope(user, klass)
        policy = get_policy(klass)
        policy::Scope.new(user, klass).resolve
      end

      def self.auth_error_message(user, scope)
        actor = "#{user.class.name} with id '#{user.id}'"
        target = scope[:type].classify
        unless %i[create update_all].include? scope[:scope_type]
          target += " with id '#{scope[:scope][:arguments].first}'"
        end
        msg = "#{actor} is not authorized to #{scope[:scope_type]} #{target}"

        [{ title: msg,
           source: { pointer: scope[:path] } }].to_json
      end

      def self.get_entity_authorization(scope, user)
        if %i[create update_all index destroy_all].include?(scope[:scope_type])
          target = scope[:klass]
        elsif scope[:scope]
          # TODO: deprecate this part of the clause following write endpoint refactor
          target = scope[:scope][:base].send(scope[:scope][:method],
                                             *scope[:scope][:arguments])
        else
          target = scope[:klass].find(scope[:query][:id])
        end

        Pundit.policy!(user, target).send(get_policy_name(scope[:scope_type]))
      end

      def self.authorize(scopes, user)
        scopes.each do |s|
          allowed = get_entity_authorization(s, user)
          unless allowed
            raise DeepUnrest::Unauthorized, auth_error_message(user, s)
          end
        end
      end
    end
  end
end
