# frozen_string_literal: true

module MCP
  module Tools
    class MoveProject < Base
      UNMOVED = "could not move the project"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          direction: { type: "string", enum: Blog::Types::ProjectMove.values },
          id: API::Schema::ID,
        },
        required: %w[id direction],
      }.freeze

      description "Move one live project a step up or down the order /projects shows. The first project " \
                  "cannot go up nor the last down; that call moves nothing and answers moved false"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, direction:, server_context:)
          case dep(:move_project, server_context).call(id, direction)
          in Success(_) then answer(id:, direction:, moved: true)
          in Failure(:not_moved) then answer(id:, direction:, moved: false)
          in Failure(:not_found) then refuse("no live project has the ID #{id}")
          else refuse(UNMOVED)
          end
        end
      end
    end
  end
end
