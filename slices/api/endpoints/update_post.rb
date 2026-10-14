# frozen_string_literal: true

module API
  module Endpoints
    class UpdatePost < PostWriteEndpoint
      INTENTS = {
        Blog::Types::PostStatus["draft"] => Blog::Types::PostIntent["draft"],
        Blog::Types::PostStatus["published"] => Blog::Types::PostIntent["save"],
        Blog::Types::PostStatus["scheduled"] => Blog::Types::PostIntent["publish"],
      }.freeze
      PAST = [
        "publish_at needs a time still to come on a scheduled post, which update_post never publishes;",
        "publish_post is the tool that publishes a post",
      ].join(" ").freeze
      SCHEDULED = Blog::Types::PostStatus["scheduled"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          **FIELDS,
          edit_note: {
            type: "string",
            description:
              "what changed and why, in markdown, up to #{::Posts::Contracts::PostContract::EDIT_NOTE_LIMIT} " \
              "characters; needed when the body of a published post changes, and shown to readers on the post",
          },
        },
        required: ["id"],
      }.freeze

      include Deps[post_queries: "posts.repos.post_queries", save_post: "posts.operations.save_post"]

      def handle(id:, **given)
        post = post_queries.by_id(id)
        return missing(id) unless post

        now = Time.now
        return invalid(publish_at: [PAST]) if post.status == SCHEDULED && past?(given, now)

        saved(save_post.call(post.form.merge(form(given)), id:, intent: INTENTS.fetch(post.status), now:), id)
      end

      private

      def past?(given, now)
        return false unless given.key?(:publish_at)

        time = Blog::Types::LocalTime[given[:publish_at]]
        time.nil? || (time.is_a?(Time) && time <= now)
      end
    end
  end
end
