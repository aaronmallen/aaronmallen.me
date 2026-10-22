# frozen_string_literal: true

module Admin
  module Operations
    class BuildContactsPage
      SYNC = Blog::Types::SyncName["contacts"]

      include Deps[
        networks: "social_networks.all",
        person_queries: "contacts.repos.person_queries",
        sync_state_queries: "record.repos.sync_state_queries",
      ]

      def call(params)
        list = {
          query: Blog::Types::OptionalText[params[:q]], show: Blog::Types::ContactShowParam[params[:show]],
          label: Blog::Types::OptionalText[params[:label]],
        }

        {
          people: person_queries.listed(**list), list:, count: person_queries.count, labels: person_queries.labels,
          searchable:, synced_at: person_queries.last_synced_at, sync_failed: !sync_state_queries.failure(SYNC).nil?,
        }
      end

      private

      def searchable
        Blog::Types::NetworkName.values.select { networks.fetch(it).then { it.respond_to?(:search) && it.configured? } }
      end
    end
  end
end
