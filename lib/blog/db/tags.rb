# frozen_string_literal: true

module Blog
  module DB
    module Tags
      def by_names(names) = where(name: names)

      def claim(names)
        return Dry::Core::Constants::EMPTY_HASH if names.empty?

        insert_missing(names)

        by_names(names).to_a.to_h { [it[:name], it[:id]] }
      end

      def counts_by_color = unordered.select(:color) { integer.count(id).as(:count) }.group(:color)

      def in_name_order = order(self[:name].asc)

      def next_color = least_used(color_counts)

      private

      def color_counts
        Blog::Types::TagColor.values.to_h { [it, 0] }.merge(counts_by_color.to_a.to_h { [it[:color], it[:count]] })
      end

      def insert_missing(names)
        now = Time.now
        counts = color_counts

        names.each do |name|
          color = least_used(counts)
          counts[color] += 1

          upsert(name:, color:, created_at: now, updated_at: now)
        end
      end

      def least_used(counts)
        fewest = counts.values.min

        counts.select { |_, used| used == fewest }.keys.sample
      end
    end
  end
end
