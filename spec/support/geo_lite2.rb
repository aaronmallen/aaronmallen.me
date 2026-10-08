# frozen_string_literal: true

require "rubygems/package"
require "stringio"
require "zlib"

module GeoLite2Database
  CITIES = { "81.2.69.0/24" => "London", "198.51.100.0/24" => "Nowhere" }.freeze
  COUNTRIES = { "1.2.3.0/24" => "US", "81.2.69.0/24" => "GB", "2001:db8::/32" => "DE" }.freeze
  COUNTRY_NAMES = { "DE" => "Germany", "GB" => "United Kingdom", "US" => "United States" }.freeze
  CREDENTIALS = { account_id: "123456", license_key: "license" }.freeze
  DOWNLOAD_URL = "https://download.maxmind.com/geoip/databases/GeoLite2-City/download"
  ENTRY = "GeoLite2-City_20260928/GeoLite2-City.mmdb"
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

  def geo_lite2_database(countries = COUNTRIES, cities: CITIES)
    networks = countries.keys | cities.keys
    networks.reduce(Mmdb.new) { |mmdb, network| mmdb.add(network, place(countries[network], cities[network])) }.to_s
  end

  private

  def named(name) = name && { "names" => { "en" => name } }

  def place(code, city)
    country = named(COUNTRY_NAMES.fetch(code, code))&.merge("iso_code" => code)

    { "city" => named(city), "country" => country }.compact
  end
end

RSpec.configure do |config|
  config.include GeoLite2Database
end
