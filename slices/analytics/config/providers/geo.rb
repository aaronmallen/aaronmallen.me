# frozen_string_literal: true

Analytics::Slice.register_provider :geo do
  start do
    @databases = Analytics::Providers::GeoProvider::Databases.new
    geo_lite2 = Analytics::Providers::GeoProvider.geo_lite2(target["settings"], target["http"])

    register "geo.countries", Analytics::Providers::GeoProvider.countries(target.app.root, @databases)
    register "geo.geo_lite2.client", geo_lite2
  end

  stop do
    @databases.close
  end
end
