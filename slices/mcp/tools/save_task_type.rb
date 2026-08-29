# frozen_string_literal: true

module MCP
  module Tools
    class SaveTaskType < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: {
          color: {
            type: "string",
            enum: Blog::Types::TagColor.values,
            description: "the least used colour when you add a type and leave it out",
          },
          icon: {
            type: "string",
            description: "a Font Awesome free solid icon name, such as broom, or an empty string for none",
          },
          id: { type: "integer", description: "the type to rename; leave it out to add a new type" },
          name: { type: "string" },
        },
        required: ["name"],
      }.freeze

      description "Add a task type, or rename and recolour one by its ID. A field you leave out keeps what it has"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(name:, server_context:, id: nil, **fields)
          case save_task_type(server_context).call(fields.merge(name:), id:)
          in Success(type) then answer(type_entry(type))
          in Failure(:not_found) then no_type(id)
          in Failure[:invalid, errors] then refuse(complaint(errors))
          else unsaved
          end
        end
      end
    end
  end
end
