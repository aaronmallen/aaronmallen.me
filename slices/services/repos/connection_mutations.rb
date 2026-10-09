# frozen_string_literal: true

module Services
  module Repos
    class ConnectionMutations < DB::Repo
      root :service_connections

      stamped_commands :create

      def add(credentials:, **columns)
        create(credentials: Blog::Encryptor.new.seal(JSON.generate(credentials)), **columns)
      end

      def remove(id) = service_connections.by_pk(id).delete
    end
  end
end
