# frozen_string_literal: true

module Projects
  module Repos
    class WorkEntryQueries < DB::Repo
      def all = work_entries.in_order.to_a

      def between(from:, to:) = work_entries.overlapping(from.year, to.year).in_order.to_a

      def by_id(id) = work_entries.by_pk(id).one
    end
  end
end
