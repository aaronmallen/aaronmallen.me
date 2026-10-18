# frozen_string_literal: true

module Admin
  module Operations
    class BuildServicesPage
      include Deps[
        "operations.build_settings_tabs",
        "operations.list_services",
        api_token_queries: "api.repos.api_token_queries",
        check_service: "operations.check_service",
        client_queries: "api.repos.client_queries",
        definition_queries: "services.repos.definition_queries",
      ]

      def call(services: Blog::Constants::EMPTY_HASH, tokens: Blog::Constants::EMPTY_HASH)
        listed = listing(**services)

        {
          services: listed,
          tokens: {
            errors: Blog::Constants::EMPTY_HASH, minted: nil, name: Blog::Constants::EMPTY_STRING,
            tokens: api_token_queries.live, **tokens,
          },
          clients: { clients: client_queries.connected },
          tabs: build_settings_tabs.call(services: listed[:rows].size),
        }
      end

      private

      def listing(connect: nil, selected: nil, **)
        listing = list_services.call
        connectable = definition_queries.all.select { check_service.checks?(it.id) }

        listing.merge(
          connect: connectable.find { it.id == connect.to_s }, connectable: connectable.map(&:id),
          selected: listing[:rows].find { it.key == selected.to_s }, **,
        )
      end
    end
  end
end
