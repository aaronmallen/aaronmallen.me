# frozen_string_literal: true

module Analytics
  module Repos
    class CountryQueries
      include Deps["geo.countries", "geo.geo_lite2.client"]

      def database_failure = (countries.failure if client.configured?)
    end
  end
end
