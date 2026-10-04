# frozen_string_literal: true

module MCP
  module Tools
    class TagPosts < Base
      description "Add one public tag to up to 100 blog posts at once. One that is missing tags none"
      input_schema(API::Endpoints::TagPosts::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:tag_posts, input, server_context)
      end
    end
  end
end
