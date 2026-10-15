# frozen_string_literal: true

module Analytics
  module Operations
    class RankRows
      FIGURES = %i[views visitors].freeze

      def call(rows, key:, figures: FIGURES, named: nil, by: :visitors)
        keys = Array(key)
        merged = rows.group_by { it.values_at(*keys) }.map do |values, found|
          { **keys.zip(values).to_h, **name(found, named), **figures.to_h { [it, total(found, it)] } }
        end

        merged.sort_by { standing(it, keys, by) }
      end

      private

      def name(rows, named) = named ? { named => rows.filter_map { it[named] }.last } : {}

      def standing(row, keys, by)
        [row[by] ? 0 : 1, -row[by].to_i, -row[:views].to_i, *row.values_at(*keys).map(&:to_s)]
      end

      def total(rows, figure)
        known = rows.filter_map { it.fetch(figure) }
        known.sum unless known.empty?
      end
    end
  end
end
