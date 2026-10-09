# frozen_string_literal: true

module Services
  module Relations
    class ServiceConnections < Blog::DB::Relation
      schema :service_connections, infer: true

      def in_list_order = order(self[:provider], self[:label], self[:id])
    end
  end
end
