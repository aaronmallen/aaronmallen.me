# frozen_string_literal: true

module Services
  module Repos
    class AppMutations < DB::Repo
      root :service_apps

      stamped_commands :create

      def replace(provider:, host:, credentials:, **columns)
        transaction do
          service_apps.where(provider:, host:).delete
          create(provider:, host:, credentials: Blog::Encryptor.new.seal(JSON.generate(credentials)), **columns)
        end
      end
    end
  end
end
