# frozen_string_literal: true

module Projects
  module Repos
    class WorkEntryRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands delete: :by_pk

      def all = work_entries.in_order.to_a

      def between(first, last) = work_entries.overlapping(first, last).in_order.to_a

      def next_position = work_entries.last_position + 1
    end
  end
end
