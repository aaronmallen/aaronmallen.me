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

          settle(response, save_short_link.call(id, params), SAVED, routes.path(:admin_links)) do |errors|
            invalid(response, id, params, errors)
          end
        end

        private

        def invalid(response, id, params, errors)
          link = short_link_queries.find(id)
          halt :not_found unless link

          values = %i[destination code title].to_h { [it, Blog::Types::Text[params[it]]] }
          unprocessable(response, edit_view, link:, check: short_link_queries.check(link), values:, errors:)
        end
      end
    end
  end
end
