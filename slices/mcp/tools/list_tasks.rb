# frozen_string_literal: true

module MCP
  module Tools
    class ListTasks < Base
      description "List tasks in any status, newest first, each with its tags, links both ways, sprint day " \
                  "and completed time. A task sits in the window when it was created or finished on a day " \
                  "inside it; leave from or to out to leave that end open, and both out to list every task. " \
                  "count gives the tasks on this page. #{Blog::Paging::USAGE}"
      input_schema(API::Endpoints::ListTasks::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:list_tasks, input, server_context)
      end
    end
  end
end
