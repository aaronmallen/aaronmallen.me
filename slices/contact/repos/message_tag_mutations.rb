# frozen_string_literal: true

module Contact
  module Repos
    class MessageTagMutations < DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["private"]

      root :message_tags

      def add(message_id, name)
        tag_id = tags.claim([name], scope: TAG_SCOPE).fetch(name)

        message_tags.dataset.insert_conflict.insert(message_id:, tag_id:)
      end

      def remove(message_id, name)
        message_tags.for_owner(message_id).where(tag_id: tags.in_scope(TAG_SCOPE).by_names([name]).pluck(:id)).delete
      end
    end
  end
end
