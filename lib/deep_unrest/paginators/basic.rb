module DeepUnrest
  module Paginators
    module Basic
      def self.get_page(item, results)
        page = [item[:query][:page] || 1].max
        page_size = item[:query][:pageSize] || DeepUnrest.page_size
        results.limit(page_size).offset(page - 1)
      end
    end
  end
end
