# frozen_string_literal: true

module Blog
  module DB
    module Taggings
      NAME = Sequel[:tags][:name]

      def add(id, tag_ids)
        command(:create, result: :many).call(tag_ids.map { { owner_key => id, tag_id: it } }) unless tag_ids.empty?
      end

      def for_owner(id) = where(owner_key => id)

      def holding_every(names)
        folded = names.map { it.to_s.downcase }.uniq
        owner = self[owner_key].qualified
        matched = unordered.join(:tag).where(NAME => folded)

        matched.group(owner).having(Sequel.function(:count, NAME).distinct => folded.length).select(owner)
      end

      def replace(id, tag_ids)
        for_owner(id).exclude(tag_id: tag_ids).delete
        add(id, tag_ids - for_owner(id).pluck(:tag_id))
      end
    end
  end
end
