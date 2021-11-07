module DeepUnrest
  module Concerns
    module ResourceScope
      extend ActiveSupport::Concern

      class_methods do
        def records_base(opts)
          opts&.dig(:context, :scope) || super(opts)
        end
      end
    end
  end
end
