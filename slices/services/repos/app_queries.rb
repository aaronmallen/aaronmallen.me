# frozen_string_literal: true

module Services
  module Repos
    class AppQueries < DB::Repo
      def find(provider, host) = service_apps.where(provider: provider.to_s, host:).one
    end
  end
end
