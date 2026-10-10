# frozen_string_literal: true

module Projects
  module Repos
    class WorkEntryMutations < Blog::DB::Repo
      root :work_entries

      stamped_commands :create
      commands delete: :by_pk

      def next_position = work_entries.last_position + 1
    end
  end
end
