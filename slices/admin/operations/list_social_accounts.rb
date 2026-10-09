# frozen_string_literal: true

module Admin
  module Operations
    class ListSocialAccounts
      include Deps["i18n", connection_queries: "services.repos.connection_queries"]

      def call(selected: nil)
        Blog::Types::NetworkName.values.flat_map do |network|
          connection_queries.for(network).map { account(it, network, selected) }
        end
      end

      private

      def account(connection, network, selected)
        Structs::SocialAccount.new(
          id: connection.id, label: connection.label, network:,
          network_label: i18n.t(Structs::Network::LABELS.fetch(network)),
          selected: selected.nil? || selected.include?(connection.id),
        )
      end
    end
  end
end
