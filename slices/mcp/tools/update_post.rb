# frozen_string_literal: true

module MCP
  module Tools
    class UpdatePost < PostWrite
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
          id: API::Schema::ID,
          **FIELDS,
          edit_note: {
            type: "string",
            description:
              "what changed and why, in markdown, up to 500 characters; " \
              "needed when the body of a published post changes, and shown to readers on the post",
          },
        },
        required: ["id"],
      }.freeze

      description "Change one blog post: its body or any other field. A field you leave out keeps what it has. " \
                  "A draft stays a draft and a scheduled post stays scheduled, at its new publish time if you " \
                  "give one, which has to be still to come. A published post keeps its slug and its publish " \
                  "time, and a change to its body needs an edit_note saying what changed and why. " \
                  "The post takes the same checks the admin editor makes, and a refusal names each field at fault"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:, **given)
          post = post_by_id(server_context).call(id)
          return missing(id) unless post

          now = Time.now
          return refuse(PAST) if post.status == SCHEDULED && past?(given, now)

          params = ::Posts::PostForm.call(post).merge(form(given))

          saved(save_post(server_context).call(params, id:, intent: INTENTS.fetch(post.status), now:), id)
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
end
