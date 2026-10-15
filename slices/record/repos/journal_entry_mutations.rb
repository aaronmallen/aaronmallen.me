# frozen_string_literal: true

module Record
  module Repos
    class JournalEntryMutations < Blog::DB::Repo
      root :journal_entries

      stamped_commands :create, :update
      tagged_by :journal_entry_tags
      commands delete: :by_pk
    end
  end
end
