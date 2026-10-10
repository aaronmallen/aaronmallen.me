# frozen_string_literal: true

module Contact
  module Repos
    class MessageTagMutations < Blog::DB::Repo
      root :message_tags

      def add(message_id, name) = message_tags.tag(message_id, [name], tags)

      def remove(message_id, name) = message_tags.untag(message_id, [name], tags)

      def replace(message_id, names) = message_tags.retag(message_id, names, tags)
    end
  end
end
