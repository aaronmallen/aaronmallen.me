# frozen_string_literal: true

module MCP
  module Tools
    class DeletePosts < Base
      description "Delete up to 100 draft blog posts at once. One that is missing or not a draft deletes none. No undo"
      input_schema(API::Endpoints::DeletePosts::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_posts, input, server_context)
      end
    end
  end
end
