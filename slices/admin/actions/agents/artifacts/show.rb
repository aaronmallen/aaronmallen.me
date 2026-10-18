# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class Show < Action
          include Deps[build_artifact_page: "operations.build_artifact_page"]

          def handle(request, response)
            params = request.params
            page = build_artifact_page.call(
              record_id(request), number: Blog::Types::IdParam[params[:version]], records: { query: params[:record_q] },
            )
            not_found(response) unless page

            response.render(view, **page)
          end
        end
      end
    end
  end
end
