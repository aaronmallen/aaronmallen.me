# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class DeadJobMenu < Action
        include Deps[attention_queries: "activity.repos.attention_queries"]

        def handle(request, response)
          response.render(view, job: attention_queries.dead_job(request.params[:jid]) || halt(404))
        end
      end
    end
  end
end
