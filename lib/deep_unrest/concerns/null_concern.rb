module DeepUnrest
  module Concerns
    module NullConcern
      extend ActiveSupport::Concern
      included do
        before_action :issue_warning
      end

      protected

      def issue_warning
        # TODO: get link to docs for this
        logger.info 'Warning: no concern set for DeepUnrest. Read the docs.'
      end
    end
  end
end
