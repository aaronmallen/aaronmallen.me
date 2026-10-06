# frozen_string_literal: true

module Projects
  module Repos
    class WorkEntryRepo < Blog::DB::Repo
      stamped_commands :create
      commands delete: :by_pk

      def all = work_entries.in_order.to_a

      def between(first, last) = work_entries.overlapping(first, last).in_order.to_a

      def by_id(id) = work_entries.by_pk(id).one

      def next_position = work_entries.last_position + 1
    end
  end
end
