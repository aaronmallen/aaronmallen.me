# frozen_string_literal: true

module MediaStore
  CLIENT_KEYS = %w[store.client media.store.client].freeze
  SETTINGS = {
    access_key: "access-key",
    bucket: "photos",
    endpoint: "https://store.example",
    path_style: true,
    region: "us-east-1",
    secret_key: "secret-key",
  }.freeze

  def connect_media_store(**settings)
    Media::Slice.start(:store)
    allow(Hanami.app.settings).to receive(:media_store).and_return(SETTINGS.merge(settings))
    client = Media::Providers::StoreProvider.client(Hanami.app["settings"])

    CLIENT_KEYS.each { replace_component(it, client) }
  end

  def media_store_url(key) = "#{SETTINGS[:endpoint]}/#{SETTINGS[:bucket]}/#{key}"
end

RSpec.configure do |config|
  config.include MediaStore
end
