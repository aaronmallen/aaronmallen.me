# frozen_string_literal: true

module MCP
  module Tools
    class ComposeAnnouncement < Base
      description "Compose the announcement one blog post sends to social networks when it goes out: its own " \
                  "announcement text, or its title and link when it has none. Nothing is sent"
      input_schema(API::Schema.by_id)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          post = dep(:post_queries, server_context).by_id(id)
          return refuse(API::Wording.missing("blog post", id)) if post.nil?

          answer(id: post.id, announcement: dep(:compose_announcement, server_context).call(post))
        end
      end
    end
  end
end
