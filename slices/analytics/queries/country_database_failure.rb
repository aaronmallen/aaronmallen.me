# frozen_string_literal: true

module Analytics
  module Queries
    class CountryDatabaseFailure
      include Deps["geo.countries", "geo.geo_lite2.client"]

      def call
        return nil unless client.configured?

        countries.failure
      end
    end
  end
end
