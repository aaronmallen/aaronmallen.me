# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class Jobs < Action
        include Deps[
          build_settings_tabs: "operations.build_settings_tabs",
          cron_queries: "activity.repos.cron_queries",
          job_queries: "activity.repos.job_queries",
        ]

        def handle(request, response)
          cron = cron_queries.entries
          work = work(request)
          health = work.fetch(:health)
          work[:job] = job(request) unless health.down?

          filter = Blog::Types::CronFilterParam[request.params[:cron]]

          response.render(view, **work, cron:, cron_filter: filter, tabs: tabs(health, cron))
        end

        private

        def job(request)
          set = Blog::Types::JobSetParam[request.params[:open]]
          jid = request.params[:jid]
          job_queries.set_job(set, jid) if set && jid.is_a?(String)
        end

        def page(request) = Blog::Structs::Page.new(number: page_number(request), size: page_size)

        def tabs(health, cron)
          jobs = build_settings_tabs.jobs(flagged: health.flagged, failed: cron.count(&:failed?))

          build_settings_tabs.call(jobs:)
        end

        def work(request)
          job_queries.overview(
            open: Blog::Types::JobSetParam[request.params[:set]], page: page(request), queue: request.params[:queue],
          )
        end
      end
    end
  end
end
