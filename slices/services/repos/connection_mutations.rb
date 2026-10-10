# frozen_string_literal: true

module Services
  module Repos
    class ConnectionMutations < Blog::DB::Repo
      root :service_connections

      commands delete: :by_pk

      stamped_commands :create

      def add(credentials:, **columns)
        create(credentials: Blog::Encryptor.new.seal(JSON.generate(credentials)), **columns)
      end
    end
  end
end
