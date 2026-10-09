# frozen_string_literal: true

module Admin
  module Operations
    class ListSocialAccounts
      include Deps[
        "settings",
        connection_queries: "services.repos.connection_queries",
        list_networks: "operations.list_networks",
      ]

      def call
        list_networks.call.select(&:configured).flat_map { accounts(it.name) }
      end

      private

      def accounts(name) = name == Blog::Types::NetworkName["bluesky"] ? bluesky_accounts : [mastodon_account]

      def bluesky_accounts = connection_queries.for(Blog::Types::NetworkName["bluesky"]).map(&:label)

      def mastodon_account
        url = settings.mastodon[:url]
        Blog::Types::Normalized::Host.call(url) { url.to_s }
      end
    end
  end
end
