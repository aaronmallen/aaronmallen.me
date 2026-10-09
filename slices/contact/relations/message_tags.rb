# frozen_string_literal: true

module Contact
  module Relations
    class MessageTags < Blog::DB::Relation
      use :taggings, owner_key: :message_id

      schema :message_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
