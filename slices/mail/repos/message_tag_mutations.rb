# frozen_string_literal: true

module Mail
  module Repos
    class MessageTagMutations < Blog::DB::Repo
      root :mail_thread_tags

      def add(thread_id, name) = mail_thread_tags.tag(thread_id, [name], tags)

      def remove(thread_id, name) = mail_thread_tags.untag(thread_id, [name], tags)

      def replace(thread_id, names) = mail_thread_tags.retag(thread_id, names, tags)
    end
  end
end
