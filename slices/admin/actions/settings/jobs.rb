# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class Jobs < Action
        include Deps[job_queries: "activity.repos.job_queries"]

        def handle(request, response)
          health = job_queries.health
          return response.render(view, health:) if health.down?

          response.render(
            view,
            health:, running: job_queries.running, queues: job_queries.queue_list, queue: queue(request),
          )
        end

        private

        def queue(request)
          name = request.params[:queue]
          job_queries.queue(name, Blog::Structs::Page.new(number: page_number(request), size: page_size)) if name
        end
      end
    end
  end
end
