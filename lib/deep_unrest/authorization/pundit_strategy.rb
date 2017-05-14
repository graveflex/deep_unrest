# frozen_string_literal: true

module DeepUnrest
  module Authorization
    class PunditStrategy
      def self.get_policy_name(method)
        "#{method}?".to_sym
      end

      def self.get_authorized_scope(user, klass)
        Pundit.policy_scope!(user, klass)
      end

      def self.auth_error_message(user, scope)
        actor = "#{user.class.name} with id '#{user.id}'"
        target = scope[:type].classify
        unless %i[create update_all].include? scope[:scope_type]
          target += " with id '#{scope[:scope][:arguments].first}'"
        end
        "#{actor} is not authorized to #{scope[:scope_type]} #{target}"
      end

      def self.get_entity_authorization(scope, user)
        if scope[:scope]
          target = scope[:scope][:base].send(scope[:scope][:method],
                                             *scope[:scope][:arguments])
        else
          target = scope[:klass]
        end
        Pundit.policy!(user, target).send(get_policy_name(scope[:scope_type]))
      end

      def self.authorize(scopes, user)
        scopes.each do |s|
          allowed = get_entity_authorization(s, user)
          unless allowed
            raise Pundit::NotAuthorizedError, auth_error_message(user, s)
          end
        end
      end
    end
  end
end
