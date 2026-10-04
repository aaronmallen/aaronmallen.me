# frozen_string_literal: true

module BackupStore
  SETTINGS = {
    access_key: "backup-access-key",
    bucket: "backups",
    endpoint: "https://backups.example",
    path_style: true,
    region: "us-east-1",
    secret_key: "backup-secret-key",
  }.freeze

  def backup_store_url(key = nil) = [SETTINGS[:endpoint], SETTINGS[:bucket], key].compact.join("/")

  def connect_backup_store(**settings)
    Backups::Slice.start(:backup_store)
    allow(Hanami.app.settings).to receive(:backup_store).and_return(SETTINGS.merge(settings))
    replace_component("backup_store.client", Backups::Providers::StoreProvider.client(Hanami.app["settings"]))
  end

  def stub_backup_listing(*keys)
    contents = keys.map { "<Contents><Key>#{it}</Key><Size>1</Size></Contents>" }.join
    body = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
        <Name>#{SETTINGS[:bucket]}</Name><KeyCount>#{keys.size}</KeyCount><IsTruncated>false</IsTruncated>#{contents}
      </ListBucketResult>
    XML

    stub_request(:get, backup_store_url).with(query: hash_including("list-type" => "2")).to_return(body:)
  end
end

RSpec.configure do |config|
  config.include BackupStore
end
