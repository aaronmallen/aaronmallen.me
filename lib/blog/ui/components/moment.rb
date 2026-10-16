# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Moment < Component
        prop :at, Blog::Types::Time | Blog::Types::Date
        prop :format, Blog::Types::Symbol, default: :medium
        prop :attributes, Blog::Types::Hash, :**

        def view_template(&content)
          local = @at.is_a?(::Date) ? @at : TimeZone.local(@at)

          time(**@attributes, datetime: local.iso8601, &content || proc { l(local, format: @format) })
        end
      end
    end
  end
end
