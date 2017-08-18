module DeepUnrest
  module Concerns
    module MapTempIds
      extend ActiveSupport::Concern

      included do
        attr_accessor :deep_unrest_context
        attr_accessor :deep_unrest_temp_id
        after_create :map_temp_id
      end

      def map_temp_id
        # return unless @deep_unrest_temp_id
        temp_id_map = DeepUnrest::ApplicationController.class_variable_get(
          '@@temp_ids'
        )
        return unless temp_id_map && @deep_unrest_temp_id
        temp_id_map[@deep_unrest_context][@deep_unrest_temp_id] = id
      end
    end
  end
end
