# frozen_string_literal: true

module MCP
  module Tools
    class PublishPost < PostWrite
      PUBLISH = Blog::Types::PostIntent["publish"]
      PUBLISHED = Blog::Types::PostStatus["published"]
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Publish one blog post as it stands. It goes out now, or on its publish time when that is still " \
                  "to come, and its announcement and webmentions go with it when the post has them on. " \
                  "A published post cannot be called back. " \
                  "The post takes the same checks the admin editor makes, and a refusal names each field at fault"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          post = post_by_id(server_context).call(id)
          return missing(id) unless post
          return refuse("blog post #{id} is already published") if post.status == PUBLISHED

          saved(save_post(server_context).call(stored(post), id:, intent: PUBLISH), id)
        end
      end
    end
  end
end
