# frozen_string_literal: true

module Admin
  module Operations
    class ListNetworks
      include Deps["i18n", "settings", networks: "social.networks.all"]

      def call(selected: nil)
        Blog::Types::NetworkName.values.map { network(it, selected) }
      end

      private

      def label(name) = i18n.t(Structs::Network::LABELS.fetch(name))

      def network(name, selected)
        client = networks.fetch(name)
        configured = client.configured?

        Structs::Network.new(
          configured:, label: label(name), limit: client.limit, max_bytes: client.max_bytes, name:,
          reserved_per_url: client.reserved_per_url,
          selected: configured && (selected.nil? || selected.include?(name)), tagged_host:,
        )
      end

      def tagged_host = Blog::Types::Normalized::Host.call(settings.site[:url]) { Blog::Constants::EMPTY_STRING }
    end
  end
end
