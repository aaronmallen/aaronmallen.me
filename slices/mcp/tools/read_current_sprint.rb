# frozen_string_literal: true

module MCP
  module Tools
    class ReadCurrentSprint < TaskTool
      SCHEMA = { additionalProperties: false }.freeze

      description "Read today's sprint and every task in it, in order. Opening it starts the sprint when " \
                  "today has none yet and carries in what the day before left open, as the admin does"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:)
          case current_sprint(server_context).call
          in Success(sprint) then answer(sprint_entry(sprint).merge(tasks: listed(sprint, server_context)))
          else refuse("could not open today's sprint")
          end
        end

        private

        def listed(sprint, server_context)
          types = type_names(server_context)

          tasks_in_sprint(server_context).call(sprint.id).map { task_entry(it, types, sprint.sprint_date) }
        end
      end
    end
  end
end
