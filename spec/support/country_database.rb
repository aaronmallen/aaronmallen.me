# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module CountryDatabase
  def connect_maxmind_client(**)
    connect_maxmind(**)
    replace_component("geo.geo_lite2.client", geo_provider.geo_lite2(Hanami.app["settings"], Hanami.app["http"]))
  end

  def country_database_path = country_database_root.join(geo_provider::DATABASE_PATH)

  def disconnect_maxmind_client
    allow(Hanami.app.settings).to receive(:maxmind).and_return({})
    replace_component("geo.geo_lite2.client", geo_provider.geo_lite2(Hanami.app["settings"], Hanami.app["http"]))
  end

  def stub_maxmind_download(**response)
    stub_request(:get, GeoLite2Database::DOWNLOAD_URL).with(query: { suffix: "tar.gz" }).to_return(response)
  end

  def use_country_database
    @country_databases = geo_provider::Databases.new
    replace_component("geo.countries", geo_provider.countries(country_database_root, @country_databases))
  end

  def write_country_database(bytes = geo_lite2_database)
    written = country_database_path.sub_ext(".written")
    FileUtils.mkdir_p(written.dirname)
    written.binwrite(bytes)
    written.rename(country_database_path)
  end

  private

  def country_database_root = @country_database_root ||= Pathname(Dir.mktmpdir)

  def geo_provider = Analytics::Providers::GeoProvider
end

RSpec.configure do |config|
  config.include CountryDatabase

  config.after do
    @country_databases&.close
    FileUtils.remove_entry(@country_database_root) if @country_database_root
  end
end
