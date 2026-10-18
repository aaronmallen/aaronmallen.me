# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class CronEntryMenu < Action
        include Deps[cron_queries: "activity.repos.cron_queries"]

        def handle(request, response)
          entry = cron_queries.entry(request.params[:name]) || halt(:not_found)

          response.render(view, entry:, return_to: back_here(request))
        end
      end
    end
  end
end
