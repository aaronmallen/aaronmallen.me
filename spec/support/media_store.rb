# frozen_string_literal: true

module MediaStore
  SETTINGS = {
    access_key: "access-key",
    bucket: "photos",
    endpoint: "https://store.example",
    path_style: true,
    region: "us-east-1",
    secret_key: "secret-key",
  }.freeze

  def connect_media_store(**settings)
    store = Hanami.app.settings.media_store.merge(SETTINGS, settings)
    replace_component("media_store.client", ObjectStore::Provider.build(store))
  end

  def media_store_url(key) = "#{SETTINGS[:endpoint]}/#{SETTINGS[:bucket]}/#{key}"
end

RSpec.configure do |config|
  config.include MediaStore
end
