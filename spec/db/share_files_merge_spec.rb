# frozen_string_literal: true

RSpec.describe "Single shares and group files in one table", type: :request do
  let(:app) { Rack::Builder.parse_file(Hanami.app.root.join(".config/config.ru").to_s) }
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }

  before do
    allow(Hanami).to receive(:boot)
    connect_share_store
    stub_request(:head, %r{\A#{share_store_url}/})
  end

  def fetch(path) = get(path, {}, { "HTTP_HOST" => "shares.localhost" })

  def file(**) = { key: SecureRandom.hex(16), filename: "a.txt", content_type: "text/plain", byte_size: 2, ** }

  def short_code(code) = db[:short_codes].insert(code:)

  describe "the migration" do
    let(:migration) do
      path = Hanami.app.root.join("config/db/migrate/20261016001000_merge_shares_into_share_group_files.rb")
      ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
      Sequel::Migration.descendants.last
    end

    let(:group_file_id) do
      group = db[:share_groups].insert(short_code_id: short_code("deck"))
      db[:share_group_files].insert(file(share_group_id: group, filename: "b.pdf", download_count: 4))
    end

    def share_key = "a" * 32

    before do
      migration.apply(db, :down)
      group_file_id
      single = { filename: "cat.png", content_type: "image/png", alt_text: "A cat", download_count: 7 }
      db[:shares].insert(file(short_code_id: short_code("cat"), key: share_key, **single))
      migration.apply(db, :up)
    end

    it "drops the shares table" do
      expect(db.table_exists?(:shares)).to be(false)
    end

    it "carries a single share's code, key, alt text and download count over" do
      share = Shares::Slice["repos.share_queries"].by_code("cat")

      expect(share.to_h.slice(:key, :filename, :alt_text, :download_count))
        .to eq(key: share_key, filename: "cat.png", alt_text: "A cat", download_count: 7)
    end

    it "serves a single share's file under its old link" do
      stub_request(:get, share_store_url(share_key)).to_return(body: "hi")
      fetch("/cat")

      expect([last_response.status, last_response.body]).to eq([200, "hi"])
    end

    it "serves a group file under its old link with its download count" do
      file = Shares::Slice["repos.share_group_queries"].by_code("deck").share_group_files.first
      stub_request(:get, share_store_url(file.key)).to_return(body: "pd")
      fetch("/deck/#{group_file_id}")

      expect([last_response.status, last_response.body, file.download_count]).to eq([200, "pd", 4])
    end
  end

  it "refuses a file with both a code and a group" do
    group = db[:share_groups].insert(short_code_id: short_code("deck"))

    expect { db[:share_group_files].insert(file(short_code_id: short_code("cat"), share_group_id: group)) }
      .to raise_error(Sequel::CheckConstraintViolation)
  end

  it "refuses a file with neither a code nor a group" do
    expect { db[:share_group_files].insert(file) }.to raise_error(Sequel::CheckConstraintViolation)
  end

  it "keeps a group's files out of the single shares" do
    group = db[:share_groups].insert(short_code_id: short_code("deck"))
    db[:share_group_files].insert(file(share_group_id: group))

    expect(Shares::Slice["repos.share_queries"].totals).to eq(count: 0, bytes: 0)
  end
end
