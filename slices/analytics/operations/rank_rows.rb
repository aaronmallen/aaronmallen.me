# frozen_string_literal: true

module Analytics
  module Operations
    class RankRows
      FIGURES = %i[views visitors].freeze

      def call(rows, key:, figures: FIGURES, named: nil)
        merged = rows.group_by { it.fetch(key) }.map do |value, found|
          { key => value, **name(found, named), **figures.to_h { |figure| [figure, found.sum { it.fetch(figure) }] } }
        end

        merged.sort_by { [-it.fetch(:visitors), -it.fetch(:views), it.fetch(key).to_s] }
      end

      private

      def name(rows, named) = named ? { named => rows.filter_map { it[named] }.max } : {}
    end
  end
end
