# frozen_string_literal: true

module Admin
  module Operations
    class ListSavedViews
      include Deps[saved_view_queries: "saved_views.repos.saved_view_queries"]

      def call(screen, params)
        { screen:, views: saved_view_queries.all(screen:), filters: current(screen, params) }
      end

      private

      def current(screen, params)
        saved_view_queries.screen_filters(screen).each_with_object({}) do |name, kept|
          value = filter(params[name.to_sym])
          kept[name] = value unless value.empty?
        end
      end

      def filter(value)
        case value
        when ::Hash then value.to_h { |key, inner| [key.to_s, Blog::Types::Text[inner]] }.reject { _2.empty? }
        else Blog::Types::Text[value]
        end
      end
    end
  end
end
