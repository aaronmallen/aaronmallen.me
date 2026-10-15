# frozen_string_literal: true

module Services
  module Repos
    class ConnectionMutations < Blog::DB::Repo
      root :service_connections

      commands delete: :by_pk

      stamped_commands :create, :update

      def add(credentials:, **columns) = create(credentials: seal(credentials), **columns)

      def change(id, credentials: nil, **columns)
        update(id, **(credentials ? { credentials: seal(credentials) } : {}), **columns)
      end

      def reseal
        service_connections.dataset.select_map(%i[id credentials]).sum do |id, sealed|
          resealed = yield sealed
          resealed ? service_connections.where(id:, credentials: sealed).dataset.update(credentials: resealed) : 0
        end
      end

      private

      def seal(credentials) = Services::Encryptor.new.seal(JSON.generate(credentials))
    end
  end
end
