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

      private

      def seal(credentials) = Services::Encryptor.new.seal(JSON.generate(credentials))
    end
  end
end
