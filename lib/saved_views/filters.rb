# frozen_string_literal: true

module SavedViews
  module Filters
    KNOWN = {
      Blog::Types::SavedViewScreen["activity"] => %w[from to types q day],
      Blog::Types::SavedViewScreen["journal"] => %w[q to],
      Blog::Types::SavedViewScreen["posts"] => %w[status],
      Blog::Types::SavedViewScreen["tasks"] => %w[filter pool q],
    }.freeze

    module_function

    def keep(screen, filters)
      named = Blog::Types::Fields[filters].to_h { |key, value| [key.to_s, nested(value)] }

      named.slice(*names(screen))
    end

    def names(screen) = KNOWN.fetch(screen, Blog::Constants::EMPTY_ARRAY)

    def nested(value) = value.is_a?(::Hash) ? value.transform_keys(&:to_s) : value
  end
end
