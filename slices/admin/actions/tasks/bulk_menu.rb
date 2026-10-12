# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class BulkMenu < Action
        FIELDS = %i[filter q page].freeze
        PRIVATE = Blog::Types::TagScope["private"]

        include Deps[tag_queries: "tags.repos.tag_queries", task_queries: "tasks.repos.task_queries"]

        def handle(request, response)
          tasks = task_queries.by_ids(picked_ids(request))
          halt 404 if tasks.empty?

          response.render(view, tasks:, tags: tag_queries.all_in(PRIVATE), fields: request.params.to_h.slice(*FIELDS))
        end
      end
    end
  end
end
