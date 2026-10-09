# frozen_string_literal: true

module Admin
  module Operations
    class ListSocialAccounts
      include Deps["i18n", connection_queries: "services.repos.connection_queries"]

      def call(selected: nil)
        connections = Blog::Types::NetworkName.values.flat_map do |network|
          connection_queries.for(network).map { [it, network] }
        end
        picked = selected || connections.first(1).map { |connection, _| connection.id }

        connections.map { |connection, network| account(connection, network, picked) }
      end

      private

      def account(connection, network, picked)
        Structs::SocialAccount.new(
          id: connection.id, label: connection.label, network:,
          network_label: i18n.t(Structs::Network::LABELS.fetch(network)),
          selected: picked.include?(connection.id),
        )
      end
    end
  end
end
