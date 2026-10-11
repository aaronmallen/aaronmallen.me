# frozen_string_literal: true

module Mail
  module Relations
    class MailThreadTags < Blog::DB::Relation
      use :taggings, owner_key: :mail_thread_id

      schema :mail_thread_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
