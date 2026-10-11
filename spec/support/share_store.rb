# frozen_string_literal: true

require "tempfile"

module ShareStore
  SETTINGS = {
    access_key: "share-access-key",
    bucket: "shares",
    endpoint: "https://shares.example",
    path_style: true,
    region: "us-east-1",
    secret_key: "share-secret-key",
  }.freeze

  def connect_share_store(**settings)
    Shares::Slice.start(:share_store)
    allow(Hanami.app.settings).to receive(:share_store).and_return(SETTINGS.merge(settings))
    replace_component("share_store.client", Shares::Providers::StoreProvider.client(Hanami.app["settings"]))
  end

  def share_store_url(key = nil) = [SETTINGS[:endpoint], SETTINGS[:bucket], key].compact.join("/")

  def share_upload(bytes, filename, type)
    file = Tempfile.new(["share", File.extname(filename)], binmode: true)
    file.write(bytes)
    file.flush
    { tempfile: file, filename:, type: }
  end

  def upload_share(bytes = "hello", filename = "hello.txt", type = "text/plain")
    Shares::Slice["operations.upload_share"].call(share_upload(bytes, filename, type))
  end
end

RSpec.configure do |config|
  config.include ShareStore
end
