module DeepUnrest
  module Concerns
    module MapTempIds
      extend ActiveSupport::Concern

      included do
        attr_accessor :deep_unrest_context
        attr_accessor :deep_unrest_temp_id
        after_create :map_temp_id
        after_destroy :track_destruction
      end

      def map_temp_id
        temp_id_map = DeepUnrest::ApplicationController.class_variable_get(
          '@@temp_ids'
        )
        return unless temp_id_map && @deep_unrest_temp_id
        temp_id_map[@deep_unrest_context][@deep_unrest_temp_id] = id
      end

      # the client needs to know which items were destroyed so it can clean up
      # the dead entities from its local store
      def track_destruction
        destroyed = DeepUnrest::ApplicationController.class_variable_get(
          '@@destroyed_entities'
        )
        return unless destroyed
        destroyed << {
          type: self.class.to_s.pluralize.camelize(:lower),
          id: id,
          destroyed: true
        }
      end
    end
  end
end
