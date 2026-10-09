# frozen_string_literal: true

module Services
  module Repos
    class ConnectionQueries < DB::Repo
      def all = service_connections.in_list_order.to_a

      def for(provider) = service_connections.where(provider: provider.to_s).in_list_order.to_a
    end
  end
end
