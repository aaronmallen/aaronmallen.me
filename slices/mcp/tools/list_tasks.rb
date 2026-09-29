# frozen_string_literal: true

module MCP
  module Tools
    class ListTasks < TaskTool
      STATUSES = Blog::Types::TaskStatus.values.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the window, as YYYY-MM-DD" },
          page: Paging::PAGE,
          statuses: {
            type: "array",
            items: { type: "string", enum: STATUSES },
            description: "open, in_progress (started), done or canceled; every status when you leave it out",
          },
          to: { type: "string", description: "the last day of the window, as YYYY-MM-DD" },
        },
      }.freeze

      description "List tasks in any status, newest first, each with its tags, links both ways, sprint day " \
                  "and completed time. A task sits in the window when it was created or finished on a day " \
                  "inside it; leave from or to out to leave that end open, and both out to list every task. " \
                  "count gives the tasks on this page. #{Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, statuses: nil, from: nil, to: nil, page: 1)
          case window(from, to)
          in Success[first, last] then listed(Array(statuses), first..last, page(page, server_context), server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def listed(statuses, window, page, server_context)
          tasks = find_tasks(server_context).call(statuses:, from: window.begin, to: window.end, page:)

          answer(count: tasks.rows.length, tasks: tasks.rows.map { task_entry(it) }, **Paging.fields(tasks))
        end
      end
    end
  end
end
