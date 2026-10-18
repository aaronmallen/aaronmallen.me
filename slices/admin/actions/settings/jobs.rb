# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class Jobs < Action
        include Deps[cron_queries: "activity.repos.cron_queries", job_queries: "activity.repos.job_queries"]

        def handle(request, response)
          health = job_queries.health
          cron = { cron: cron_queries.entries, cron_filter: Blog::Types::CronFilterParam[request.params[:cron]] }
          return response.render(view, health:, **cron) if health.down?

          response.render(view, health:, **cron, **work(request))
        end

        private

        def job(request)
          set = Blog::Types::JobSetParam[request.params[:open]]
          jid = request.params[:jid]
          job_queries.set_job(set, jid) if set && jid.is_a?(String)
        end

        def page(request) = Blog::Structs::Page.new(number: page_number(request), size: page_size)

        def queue(request)
          name = request.params[:queue]
          job_queries.queue(name, page(request)) if name
        end

        def sets(request) = job_queries.sets(Blog::Types::JobSetParam[request.params[:set]], page(request))

        def work(request)
          {
            running: job_queries.running, queues: job_queries.queue_list, queue: queue(request), sets: sets(request),
            job: job(request),
          }
        end
      end
    end
  end
end
