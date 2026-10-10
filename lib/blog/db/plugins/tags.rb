# frozen_string_literal: true

module Blog
  module DB
    module Plugins
      module Tags
        def by_names(names) = where(name: names)

        def claim(names, scope:)
          return Blog::Constants::EMPTY_HASH if names.empty?

          insert_missing(names, scope)

          in_scope(scope).by_names(names).to_a.to_h { [it[:name], it[:id]] }
        end

        def in_name_order = order(self[:name].asc)

        def in_scope(scope) = where(scope:)

        def next_color(scope:) = least_used(color_counts(scope))

        private

        def color_counts(scope) = in_scope(scope).tally(:color, Blog::Types::TagColor.values)

        def insert_missing(names, scope)
          now = Time.now
          counts = color_counts(scope)

          names.each do |name|
            color = least_used(counts)
            counts[color] += 1

            upsert(name:, scope:, color:, created_at: now, updated_at: now)
          end
        end

        def least_used(counts)
          fewest = counts.values.min

          counts.select { |_, used| used == fewest }.keys.sample
        end
      end
    end
  end
end
