# frozen_string_literal: true

module Analytics
  module Operations
    class QueueCountryDatabase < Blog::Operation
      include Deps["geo.countries", "geo.geo_lite2.client"]

      def call
        step configured
        step missing
        Jobs::RefreshCountryDatabase.perform_async
      end

      private

      def configured = client.configured? ? Success() : Failure(:not_configured)

      def missing = countries.path.exist? ? Failure(:present) : Success()
    end
  end
end
