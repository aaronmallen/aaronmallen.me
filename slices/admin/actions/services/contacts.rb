# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Contacts < Action
        GOOGLE = Blog::Types::ServiceProvider["google"]
        TOASTS = "services_page.toasts.contacts"

        include Deps[
          change_connection: "services.operations.change_connection",
          connection_queries: "services.repos.connection_queries",
        ]

        def handle(request, response)
          connection = connection_queries.by_id(record_id(request))
          halt :not_found unless connection&.provider == GOOGLE

          options = options(request.params)
          change_connection.call(connection.id, **options)
          toast(response, "#{TOASTS}.#{toast_key(**options)}", account: connection.label)
          response.redirect_to(Helpers::ServiceTab.services(routes, selected: connection.id))
        end

        private

        def options(params)
          sync = params[:sync_contacts] == Blog::Constants::CHECKED

          { sync_contacts: sync, saves_contacts: sync && params[:saves_contacts] == Blog::Constants::CHECKED }
        end

        def toast_key(sync_contacts:, saves_contacts:)
          return :saves if saves_contacts

          sync_contacts ? :syncs : :stopped
        end
      end
    end
  end
end
