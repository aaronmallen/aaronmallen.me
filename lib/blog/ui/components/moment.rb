# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Moment < Component
        prop :at, Blog::Types::Time
        prop :format, Blog::Types::Symbol, default: :medium
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          local = TimeZone.local(@at)

          time(**@attributes, datetime: local.iso8601) { l(local, format: @format) }
        end
      end
    end
  end
end
