# frozen_string_literal: true

module MCP
  module Tools
    class UnlinkRecords < Base
      description "Remove the link between two records, whichever side it was made from"
      input_schema(API::Endpoints::UnlinkRecords::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:unlink_records, input, server_context)
      end
    end
  end
end
