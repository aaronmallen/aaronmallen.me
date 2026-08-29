# frozen_string_literal: true

module MCP
  module Tools
    class ListTaskTypes < TaskTool
      SCHEMA = { additionalProperties: false }.freeze

      description "List every task type in order, with its colour, icon and how many tasks carry it"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:)
          counts = task_counts_by_type(server_context).call

          answer(
            task_types: task_types(server_context).call.map { type_entry(it).merge(tasks: counts.fetch(it.id, 0)) },
          )
        end
      end
    end
  end
end
