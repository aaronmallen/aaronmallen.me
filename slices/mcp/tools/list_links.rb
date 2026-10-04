# frozen_string_literal: true

module MCP
  module Tools
    class ListLinks < Base
      description "List the records linked to one record, grouped by kind"
      input_schema(API::Endpoints::ListLinks::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_links, input, server_context)
      end
    end
  end
end
