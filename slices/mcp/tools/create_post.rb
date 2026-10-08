# frozen_string_literal: true

module MCP
  module Tools
    class CreatePost < PostWrite
      DRAFT = Blog::Types::PostIntent["draft"]
      SCHEMA = { additionalProperties: false, properties: FIELDS, required: ["title"] }.freeze

      description "Write a new blog post as a draft. Nothing goes out until publish_post. " \
                  "The post takes the same checks the admin editor makes, and a refusal names each field at fault"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(server_context:, **given) = saved(dep(:save_post, server_context).call(form(given), intent: DRAFT))
      end
    end
  end
end
