require 'jsonapi-resources'

module DeepUnrest
  module Paginators
    class CursorPaginator < ::JSONAPI::Paginator
      def initialize(params)
        @after = params[:after]
        @before = params[:before]
        @limit = params[:limit]
        @size = params[:size]
      end

      def apply(relation, order_options)
        return fetch_before(relation, order_options) if @before
        fetch_after(relation, order_options)
      end

      private

      def expand_order_options(opts)
      end

      def fetch_after(relation, order_options)
        order_options[:id] = :asc unless order_options[:id]
        relation
          .limit(@size)
          .order(order_options)
          .where('id >= ?', @after)
      end

      def fetch_before(relation, order_options)
        order_options[:id] = :desc unless order_options[:id]
        relation.limit(@size).order(order_options)
      end
    end
  end
end
