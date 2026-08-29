# frozen_string_literal: true

module Analytics
  module Operations
    class RefreshCountryDatabase < Blog::Operation
      include Deps["geo.countries", "geo.geo_lite2.client"]

      def call
        database = step download
        step store(database)
      end

      private

      def download
        return Failure(:not_configured) unless client.configured?

        Success(client.download)
      rescue Analytics::Error => e
        Failure([:download_failed, e.message])
      end

      def store(database)
        Success(countries.replace(database))
      rescue Analytics::Error => e
        Failure([:invalid_database, e.message])
      rescue SystemCallError => e
        Failure([:write_failed, e.message])
      end
    end
  end
end
