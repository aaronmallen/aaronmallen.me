# frozen_string_literal: true

Analytics::Slice.register_provider :geo do
  start do
    @databases = Analytics::Providers::GeoProvider::Databases.new
    settings = target["settings"]
    geo_lite2 = Analytics::Providers::GeoProvider.geo_lite2(settings, target["http"])

    register "geo.countries", Analytics::Providers::GeoProvider.countries(target.app.root, settings, @databases)
    register "geo.geo_lite2.client", geo_lite2
  end

  stop do
    @databases.close
  end
end
