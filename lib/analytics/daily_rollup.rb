# frozen_string_literal: true

module Analytics
  module DailyRollup
    FIGURES = proc { [integer.sum(views).as(:views), integer.sum(visitors).as(:visitors)] }

    def self.included(relation) = relation.extend(Ranking)

    module Ranking
      def ranks_by(column, nulls: nil)
        visitors = Sequel.function(:sum, :visitors).desc(nulls:)
        ranking = [visitors, Sequel.function(:sum, :views).desc, Sequel.asc(column)]

        define_method(:top_by_visitors) { unordered.select(column, &FIGURES).group(column).order(*ranking) }
      end
    end

    def between(from, to) = where(day: from..to)

    def for_path(path) = where(path:)

    def on(day) = where(day:)
  end
end
