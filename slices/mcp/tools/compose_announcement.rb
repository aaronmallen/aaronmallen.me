# frozen_string_literal: true

module MCP
  module Tools
    class ComposeAnnouncement < Base
      SCHEMA = { additionalProperties: false, properties: { id: API::Schema::ID }, required: ["id"] }.freeze

      description "Compose the announcement one blog post sends to social networks when it goes out: its own " \
                  "announcement text, or its title and link when it has none. Nothing is sent"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          post = post_by_id(server_context).call(id)
          return refuse("no blog post has the ID #{id}") if post.nil?

          answer(id: post.id, announcement: compose_announcement(server_context).call(post))
        end
      end
    end
  end
end
