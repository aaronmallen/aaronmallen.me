# frozen_string_literal: true

module MCP
  module Tools
    class MarkWebmentionsSpam < Base
      description "Mark up to 100 webmentions spam and stop auto-approving the authors. One that is missing marks none"
      input_schema(API::Endpoints::MarkWebmentionsSpam::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:mark_webmentions_spam, input, server_context)
      end
    end
  end
end
