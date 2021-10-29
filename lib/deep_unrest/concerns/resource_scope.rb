module DeepUnrest
  module Concerns
    module ResourceScope
      extend ActiveSupport::Concern

      included do
        def records_base(opts)
          opts[:scope] || super(opts)
        end
      end
    end
  end
end
