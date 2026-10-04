# frozen_string_literal: true

module MCP
  module Tools
    class IgnoreWebmentions < Base
      description "Hide up to 100 webmentions as ignored, leaving their authors alone. One that is missing hides none"
      input_schema(API::Endpoints::IgnoreWebmentions::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:ignore_webmentions, input, server_context)
      end
    end
  end
end
