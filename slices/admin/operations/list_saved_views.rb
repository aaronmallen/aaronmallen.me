# frozen_string_literal: true

module Admin
  module Operations
    class ListSavedViews
      FILTERS = {
        Blog::Types::SavedViewScreen["activity"] => %i[from to types q day],
        Blog::Types::SavedViewScreen["journal"] => %i[q to],
        Blog::Types::SavedViewScreen["posts"] => %i[status],
        Blog::Types::SavedViewScreen["tasks"] => %i[filter pool q],
      }.freeze

      include Deps[saved_views: "saved_views.queries.all"]

      def call(screen, params)
        { screen:, views: saved_views.call(screen:), filters: current(screen, params) }
      end

      private

      def current(screen, params)
        FILTERS.fetch(screen).each_with_object({}) do |name, kept|
          value = filter(params[name])
          kept[name.to_s] = value unless value.empty?
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
