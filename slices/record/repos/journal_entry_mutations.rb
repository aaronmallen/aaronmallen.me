# frozen_string_literal: true

module Record
  module Repos
    class JournalEntryMutations < Blog::DB::Repo
      root :journal_entries

      stamped_commands :create, :update
      commands delete: :by_pk

      def add_tag(id, name)
        update(id, {}) unless journal_entry_tags.tag(id, [name], tags).empty?
      end

      def remove_tag(id, name)
        update(id, {}) if journal_entry_tags.untag(id, [name], tags).positive?
      end

      def replace_tags(id, names) = journal_entry_tags.retag(id, names, tags)
    end
  end
end
