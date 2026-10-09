# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Create < Index
        CONNECTED = "services_page.toasts.connected"
        REFUSALS = {
          duplicate: "services_page.refusals.duplicate", refused: "services_page.refusals.refused",
          single: "services_page.refusals.single",
        }.freeze

        include Deps[connect_service: "operations.connect_service", index_view: "ui.views.services.index"]

        def handle(request, response)
          provider = request.params[:provider]

          case connect_service.call(provider, Blog::Types::Fields[request.params[:connection]])
            in Success(connection) then connected(response, connection)
            in Failure(:not_found) then halt 404
            in Failure[:invalid, errors] then rejected(response, provider, errors:)
            in Failure[:refused, reason] then rejected(response, provider, refusal: refusal(:refused, reason:))
            in Failure(:duplicate | :single => code) then rejected(response, provider, refusal: refusal(code))
          end
        end

        private

        def connected(response, connection)
          name = definition_queries.find(connection.provider).name
          toast(response, CONNECTED, name:, account: connection.label)
          response.redirect_to(routes.path(:admin_services, selected: connection.id))
        end

        def refusal(code, **) = i18n.t!(REFUSALS.fetch(code), **)

        def rejected(response, provider, **)
          response.status = 422
          response.render(index_view, **listing(provider, **))
        end
      end
    end
  end
end
