# frozen_string_literal: true

module Services
  module Repos
    class ConnectionQueries < DB::Repo
      def account?(provider, host, account_id)
        service_connections.where(provider: provider.to_s, host:, account_id:).exist?
      end

      def all = service_connections.in_list_order.to_a

      def by_id(id) = service_connections.by_pk(id).one

      def for(provider) = service_connections.where(provider: provider.to_s).in_list_order.to_a
    end
  end
end
