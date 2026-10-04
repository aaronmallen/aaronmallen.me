# frozen_string_literal: true

module MCP
  module Tools
    class ReadProject < Base
      description "Read one project by ID, such as a project hit from search: every field list_projects gives, " \
                  "created_at, updated_at and the records linked to it, grouped by kind"
      input_schema(API::Endpoints::ReadProject::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_project, input, server_context)
      end
    end
  end
end
