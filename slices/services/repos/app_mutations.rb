# frozen_string_literal: true

module Services
  module Repos
    class AppMutations < Blog::DB::Repo
      root :service_apps

      def replace(credentials:, **columns)
        sealed = Services::Encryptor.new.seal(JSON.generate(credentials))

        service_apps.store(columns.merge(credentials: sealed), Time.now)
      end

      def reseal
        service_apps.dataset.select_map(%i[id credentials]).sum do |id, sealed|
          resealed = yield sealed
          resealed ? service_apps.where(id:, credentials: sealed).dataset.update(credentials: resealed) : 0
        end
      end
    end
  end
end
