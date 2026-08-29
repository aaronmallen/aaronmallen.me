# frozen_string_literal: true

module MCP
  module Tools
    class UpdatePost < PostWrite
      INTENTS = {
        Blog::Types::PostStatus["draft"] => Blog::Types::PostIntent["draft"],
        Blog::Types::PostStatus["published"] => Blog::Types::PostIntent["save"],
        Blog::Types::PostStatus["scheduled"] => Blog::Types::PostIntent["publish"],
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: { id: { type: "integer" }, **FIELDS },
        required: ["id"],
      }.freeze

      description "Change one blog post: its body or any other field. A field you leave out keeps what it has. " \
                  "A draft stays a draft and a scheduled post stays scheduled, at its new publish time if you " \
                  "give one. A published post keeps its slug and its publish time. " \
                  "The post takes the same checks the admin editor makes, and a refusal names each field at fault"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:, **given)
          post = post_by_id(server_context).call(id)
          return missing(id) unless post

          params = stored(post).merge(form(given))

          saved(save_post(server_context).call(params, id:, intent: INTENTS.fetch(post.status)), id)
        end
      end
    end
  end
end
