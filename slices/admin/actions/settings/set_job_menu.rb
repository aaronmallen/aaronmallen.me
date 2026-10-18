# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class SetJobMenu < Action
        include Deps[job_queries: "activity.repos.job_queries"]

        def handle(request, response)
          job = job_queries.set_job(request.params[:set], request.params[:jid]) || halt(:not_found)

          response.render(view, job:, return_to: back_here(request))
        end
      end
    end
  end
end
