# frozen_string_literal: true

require "rubygems/package"
require "stringio"
require "zlib"

module GeoLite2Database
  COUNTRIES = { "1.2.3.0/24" => "US", "81.2.69.0/24" => "GB", "2001:db8::/32" => "DE" }.freeze
  CREDENTIALS = { account_id: "123456", license_key: "license" }.freeze
  DOWNLOAD_URL = "https://download.maxmind.com/geoip/databases/GeoLite2-Country/download"
  ENTRY = "GeoLite2-Country_20260928/GeoLite2-Country.mmdb"
  MODE = 0o644

  def connect_maxmind(**credentials)
    allow(Hanami.app.settings).to receive(:maxmind).and_return(CREDENTIALS.merge(credentials))
  end

  def geo_lite2_archive(database = geo_lite2_database, name: ENTRY)
    buffer = StringIO.new(+"".b)
    gzip = Zlib::GzipWriter.new(buffer)
    Gem::Package::TarWriter.new(gzip) { |tar| tar.add_file_simple(name, MODE, database.bytesize) { it.write(database) } }
    gzip.close

    buffer.string
  end

  def geo_lite2_database(countries = COUNTRIES)
    countries.reduce(Mmdb.new) { |mmdb, (network, code)| mmdb.add(network, country(code)) }.to_s
  end

  private

  def country(code) = { "country" => { "iso_code" => code, "names" => { "en" => code } } }
end

RSpec.configure do |config|
  config.include GeoLite2Database
end
