# frozen_string_literal: true

module MCP
  module Tools
    class ReadPost < Base
      KIND = "post"
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Read one blog post: its title, status, markdown body, social card fields and the records " \
                  "linked to it, grouped by kind"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          post = post_by_id(server_context).call(id)
          return refuse("no blog post has the ID #{id}") if post.nil?

          answer(
            id: post.id,
            status: post.status,
            title: post.title,
            body: post.body,
            og_title: post.og_title,
            og_image_url: post.og_image_url,
            canonical_url: post.canonical_url,
            record_links: record_links(KIND, post.id, server_context),
          )
        end
      end
    end
  end
end
