# frozen_string_literal: true

module Admin
  module Actions
    module Links
      class Update < Action
        SAVED = "links_page.toasts.saved"

        include Deps[
          edit_view: "ui.views.links.edit",
          save_short_link: "shares.operations.save_short_link",
          short_link_queries: "shares.repos.short_link_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:link]]

          case save_short_link.call(id, params)
            in Failure[:invalid, errors] then invalid(response, id, params, errors)
            in result then settle(response, result, SAVED, routes.path(:admin_links))
          end
        end

        private

        def invalid(response, id, params, errors)
          link = short_link_queries.find(id)
          halt 404 unless link

          values = %i[destination code title].to_h { [it, Blog::Types::Text[params[it]]] }
          response.status = 422
          response.render(edit_view, link:, values:, errors:)
        end
      end
    end
  end
end
