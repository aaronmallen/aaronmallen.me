# frozen_string_literal: true

require "faraday"
require "rubygems/package"
require "stringio"
require "zlib"

module Analytics
  module GeoLite2
    class Client
      class Error < Analytics::Error; end

      DATABASE = ".mmdb"
      EDITION = "GeoLite2-Country"
      SUFFIX = "tar.gz"

      def initialize(connection:)
        @connection = connection
      end

      def configured? = !connection.nil?

      def download = unpack(fetch)

      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      private

      attr_reader :connection

      def database(tar)
        tar.each { return it.read.to_s if it.full_name.end_with?(DATABASE) }

        raise Error, "The #{EDITION} archive holds no database"
      end

      def fetch
        response = get("/geoip/databases/#{EDITION}/download", suffix: SUFFIX)
        raise Error, "MaxMind answered #{response.status} for #{EDITION}" unless response.success?

        response.body.to_s.b
      end

      def get(url, **params)
        connection.get(url, params)
      rescue Faraday::Error => e
        raise Error, "The #{EDITION} download failed: #{e.message}"
      end

      def unpack(archive)
        Zlib::GzipReader.wrap(StringIO.new(archive)) do |gzip|
          Gem::Package::TarReader.new(gzip) { return database(it) }
        end
      rescue Zlib::Error, Gem::Package::TarInvalidError => e
        raise Error, "The #{EDITION} archive is unreadable: #{e.message}"
      end
    end
  end
end
