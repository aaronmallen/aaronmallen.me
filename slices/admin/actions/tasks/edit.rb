# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Edit < Action
        include Redirect
        include Deps[current_sprint: "tasks.operations.current_sprint", task_by_id: "tasks.queries.task_by_id"]

        def handle(request, response)
          halt 500 if current_sprint.call.failure?

          task = task_by_id.call(record_id(request))
          not_found(response) unless task

          response.render(view, task:, errors: Dry::Core::Constants::EMPTY_HASH, values: nil, **return_to(request))
        end
      end
    end
  end
end
