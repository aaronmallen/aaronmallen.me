# frozen_string_literal: true

module Record
  module Relations
    class JournalEntryTags < Blog::DB::Relation
      include Blog::DB::Taggings

      schema :journal_entry_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end

      def owner_key = :journal_entry_id
    end
  end
end
