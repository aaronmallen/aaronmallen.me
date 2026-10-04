# frozen_string_literal: true

module MCP
  module Tools
    class ApproveWebmentions < Base
      description "Approve up to 100 webmentions, so each shows on its blog post. One that is missing approves none"
      input_schema(API::Endpoints::ApproveWebmentions::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:approve_webmentions, input, server_context)
      end
    end
  end
end
