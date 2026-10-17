# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Projects
      class Choices < Action
        include Deps[project_queries: "projects.repos.project_queries"]

        config.formats.accept :json

        def handle(_request, response)
          response.format = :json
          response.body = JSON.generate(projects: project_queries.live_by_name.map { { key: it.key, name: it.name } })
        end

        private

        def require_sign_in(request, _response)
          halt :unauthorized unless auth_session(request).signed_in?
        end
      end
    end
  end
end
