# frozen_string_literal: true

module Blog
  module DB
    module Taggings
      def add(id, tag_ids)
        command(:create, result: :many).call(tag_ids.map { { owner_key => id, tag_id: it } }) unless tag_ids.empty?
      end

      def for_owner(id) = where(owner_key => id)

      def replace(id, tag_ids)
        for_owner(id).exclude(tag_id: tag_ids).delete
        add(id, tag_ids - for_owner(id).pluck(:tag_id))
      end
    end
  end
end
