# frozen_string_literal: true

module Services
  module Repos
    class ConnectionQueries < DB::Repo
      def all = service_connections.in_list_order.to_a

      def by_id(id) = service_connections.by_pk(id).one

      def for(provider) = service_connections.where(provider: provider.to_s).in_list_order.to_a

      def held?(provider, account_id, host = nil)
        service_connections.where(provider: provider.to_s, account_id:, host:).exist?
      end
    end
  end
end
