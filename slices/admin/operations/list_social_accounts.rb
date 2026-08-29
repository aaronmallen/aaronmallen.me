# frozen_string_literal: true

module Admin
  module Operations
    class ListSocialAccounts
      include Deps["settings", list_networks: "operations.list_networks"]

      def call
        list_networks.call.select(&:configured).map { account(it.name) }
      end

      private

      def account(name) = name == Blog::Types::NetworkName["bluesky"] ? bluesky_account : mastodon_account

      def bluesky_account = "@#{settings.bluesky[:handle]}"

      def mastodon_account
        url = settings.mastodon[:url]
        Blog::Types::Normalized::Host.call(url) { url.to_s }
      end
    end
  end
end
