# frozen_string_literal: true

module Record
  module Repos
    class JournalEntryMutations < Blog::DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["private"]

      root :journal_entries

      stamped_commands :create, :update
      commands delete: :by_pk

      def replace_tags(id, names)
        journal_entry_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))
      end
    end
  end
end
