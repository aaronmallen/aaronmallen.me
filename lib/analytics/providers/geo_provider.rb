# frozen_string_literal: true

module Analytics
  module Providers
    module GeoProvider
      class Databases
        Opened = Struct.new(:stamp, :reader)

        def initialize
          @lock = Mutex.new
          @open = {}
        end

        def close
          @lock.synchronize do
            @open.each_value { it.reader.close }
          ensure
            @open.clear
          end
        end

        def reader(path, stamp)
          @lock.synchronize do
            held = @open[path]
            @open[path] = Opened.new(stamp, yield) unless held&.stamp == stamp

            @open[path].reader
          end
        end
      end

      CONNECT_TIMEOUT = 10
      DATABASE_PATH = "tmp/maxmind/GeoLite2-City.mmdb"
      DOWNLOAD_TIMEOUT = 120
      DOWNLOAD_URL = "https://download.maxmind.com"

      class << self
        def countries(root, databases) = Countries.new(databases:, path: root.join(DATABASE_PATH))

        def geo_lite2(settings, http)
          account_id, license_key = credentials(settings)

          GeoLite2::Client.new(connection: account_id && download(http, account_id, license_key))
        end

        private

        def credentials(settings)
          found = settings.maxmind.values_at(:account_id, :license_key)

          found.all? ? found : Array.new(found.size)
        end

        def download(http, account_id, license_key)
          http.call(url: DOWNLOAD_URL, open_timeout: CONNECT_TIMEOUT, timeout: DOWNLOAD_TIMEOUT) do |faraday|
            faraday.request :authorization, :basic, account_id, license_key
          end
        end
      end
    end
  end
end
