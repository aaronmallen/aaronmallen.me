# frozen_string_literal: true

module Blog
  module DB
    module Taggings
      def for_owner(id) = where(owner_key => id)

      def replace(id, tag_ids)
        for_owner(id).delete
        command(:create, result: :many).call(tag_ids.map { { owner_key => id, tag_id: it } }) unless tag_ids.empty?
      end
    end
  end
end
