# frozen_string_literal: true

module Services
  module Repos
    class AppMutations < Blog::DB::Repo
      root :service_apps

      def replace(credentials:, **columns)
        sealed = Services::Encryptor.new.seal(JSON.generate(credentials))

        service_apps.store(columns.merge(credentials: sealed), Time.now)
      end
    end
  end
end
