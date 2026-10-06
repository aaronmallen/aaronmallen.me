# frozen_string_literal: true

RSpec.describe Backups::Slice do
  let(:client) { described_class["backup_store.client"] }

  it "boots with a client that is not configured" do
    expect(client).not_to be_configured
  end

  it "stays unconfigured when only the photo store has settings" do
    connect_media_store

    expect(client).not_to be_configured
  end

  it "leaves the photo store alone when only the backups store has settings" do
    connect_backup_store

    expect(Media::Slice["store.client"]).not_to be_configured
  end

  it "leaves the client unconfigured for an endpoint that does not parse" do
    connect_backup_store(endpoint: "not a url")

    expect(client).not_to be_configured
  end

  describe "with backup settings" do
    before do
      connect_backup_store
      stub_backup_listing
    end

    def own_key = a_request(:get, backup_store_url).with(query: hash_including({})) { signed_with?(it) }

    def signed_with?(request) = request.headers["Authorization"].include?("Credential=backup-access-key/")

    it "waits 300 seconds for the store to answer" do
      expect(client.instance_variable_get(:@connection).config.http_read_timeout).to eq(300)
    end

    it "raises its own error when the store does not answer" do
      stub_request(:delete, backup_store_url("database-1.dump")).to_timeout

      expect { client.delete("database-1.dump") }
        .to raise_error(Backups::Store::Client::Error, /\AThe backup store failed: /)
    end

    it "signs its requests with its own key" do
      client.keys(prefix: "database-")

      expect(own_key).to have_been_made
    end
  end
end
