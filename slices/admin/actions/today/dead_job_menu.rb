# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class DeadJobMenu < Action
        include Deps[attention_queries: "activity.repos.attention_queries"]

        def handle(request, response)
          jid = request.params[:jid]

          response.render(view, job: attention_queries.dead_jobs.find { it.jid == jid } || halt(404))
        end
      end
    end
  end
end
