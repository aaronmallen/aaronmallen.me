# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkPostEndpoint < BulkEndpoint
      COMPLAINTS = Posts::COMPLAINTS
      KEY = :posts
      NOUN = "blog post"
      REFUSALS = { not_draft: "blog post %s is not a draft" }.freeze
      REPLY = Helpers::Schema.object({ posts: Helpers::Schema.list(Serializers::Post.reference) }).freeze
      SCHEMA = Posts::BULK

      include Deps[act_on: "posts.operations.act_on_posts"]

      private

      def answered(posts) = serialized(Serializers::Post, posts)
    end
  end
end
