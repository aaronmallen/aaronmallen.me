# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Tags
      class Choices < Action
        PRIVATE = Blog::Types::TagScope["private"]
        PROJECT = Blog::Types::TagScope["project"]

        include Deps[tag_queries: "tags.repos.tag_queries"]

        config.formats.accept :json

        def handle(request, response)
          response.format = :json
          response.body = JSON.generate(tags: UI::Components::TagField.choices(choices(request.params[:project])))
        end

        private

        def choices(project)
          project_id = Blog::Types::IdParam[project]
          return tag_queries.all_in(PRIVATE, mail: false) if project.nil?

          project_id ? tag_queries.all_in(PROJECT, project_id:) : Blog::Constants::EMPTY_ARRAY
        end

        def require_sign_in(request, _response)
          halt :unauthorized unless auth_session(request).signed_in?
        end
      end
    end
  end
end
