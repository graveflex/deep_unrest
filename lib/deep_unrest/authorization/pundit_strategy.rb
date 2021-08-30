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
        if user
          actor = "#{user.class.name} with id '#{user.id}' is"
        else
          actor = "Anonymous users are"
        end

        target = (scope[:type] || scope[:key]).to_s.classify
        unless %i[create update_all].include? scope[:scope_type]
          target_id = (scope[:id] || scope.dig(:query, :id)).to_s.gsub('.', '')
          target += " with id '#{target_id.to_s.gsub('.', '')}'"
        end

        msg = "#{actor} not authorized to #{scope[:scope_type].to_s.downcase} #{target}"

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
          return true unless scope[:query][:id]

          target = scope[:klass].find(scope[:query][:id])
        end

        Pundit.policy!(user, target).send(get_policy_name(scope[:scope_type]))
      rescue Pundit::NotDefinedError
        false
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
