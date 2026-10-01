# frozen_string_literal: true

module API
  module Serializers
    class TaskComment < Serializer
      LOCAL = "local"

      attributes :id, :body, :author, :source, :url, :created_at

      def author(comment) = comment.remote_id ? comment.author : Blog::Owner.full_name

      def created_at(comment) = stamp(comment.created_at)

      def source(comment) = comment.provider || LOCAL
    end
  end
end
