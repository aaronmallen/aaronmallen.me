# frozen_string_literal: true

module MCP
  module Tools
    class LinkRecords < Base
      description "Link two records of any kind, such as a task and the post it was for. A pair takes one link"
      input_schema(API::Endpoints::LinkRecords::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:link_records, input, server_context)
      end
    end
  end
end
