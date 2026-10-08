# frozen_string_literal: true

module Record
  module Relations
    class JournalEntryTags < Blog::DB::Relation
      use :taggings, owner_key: :journal_entry_id

      schema :journal_entry_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
