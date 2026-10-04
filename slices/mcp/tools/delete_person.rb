# frozen_string_literal: true

module MCP
  module Tools
    class DeletePerson < Base
      description "Remove one person from the mention directory for good. Posts that mention them keep the token"
      input_schema(API::Endpoints::DeletePerson::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_person, input, server_context)
      end
    end
  end
end
