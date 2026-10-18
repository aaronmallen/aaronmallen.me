# frozen_string_literal: true

module MCP
  module Tools
    class SaveProject < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Helpers::Schema::ID.merge(description: "the project to change; leave it out to add a new one"),
          **API::Endpoints::ProjectEndpoint::PROPERTIES,
        },
      }.freeze

      description "Add a project, or change one when you give its id. On a change, a field you leave out keeps " \
                  "what it has and an empty string clears it; tags replaces the whole list. A new project needs " \
                  "a name and a visibility, and starts active with its board unpublished. Archive and restore " \
                  "it with archive_project and restore_project"
      input_schema(SCHEMA)
      operations :create_project, :update_project

      class << self
        def call(server_context:, **input)
          hand_over(input.key?(:id) ? :update_project : :create_project, input, server_context)
        end
      end
    end
  end
end
