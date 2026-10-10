# frozen_string_literal: true

module Record
  module Repos
    class JournalEntryMutations < Blog::DB::Repo
      root :journal_entries

      stamped_commands :create, :update
      commands delete: :by_pk

      def replace_tags(id, names) = journal_entry_tags.retag(id, names, tags)
    end
  end
end
