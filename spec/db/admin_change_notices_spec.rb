# frozen_string_literal: true

RSpec.describe "Admin change notices", :commits, type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }

  def short_code(code) = db[:short_codes].insert(code:)

  def sync_state(kind, **) = db[:sync_states].insert(kind:, sync: "commits", repo: "blog", synced_at: Time.now, **)

  def tag = db[:tags].insert(name: "ruby", color: "mk-blue", scope: "public")

  it "sends one for an insert" do
    expect(admin_notice { tag }).to eq("tags")
  end

  it "sends one for a change to any other column" do
    id = tag

    expect(admin_notice { db[:tags].where(id:).update(name: "rails") }).to eq("tags")
  end

  it "sends none for an update that changes only updated_at" do
    id = tag

    expect(admin_notice { db[:tags].where(id:).update(updated_at: Sequel::CURRENT_TIMESTAMP) }).to be_nil
  end

  it "sends none for a short link click" do
    id = db[:short_links].insert(short_code_id: short_code("go"), destination: "https://example.com")
    click = { click_count: Sequel[:click_count] + 1, last_clicked_at: Sequel::CURRENT_TIMESTAMP }

    expect(admin_notice { db[:short_links].where(id:).update(click) }).to be_nil
  end

  it "sends none for a share download" do
    file = { key: "0" * 32, filename: "a.txt", content_type: "text/plain", byte_size: 1 }
    id = db[:share_group_files].insert(short_code_id: short_code("file"), **file)
    count = { download_count: Sequel[:download_count] + 1 }

    expect(admin_notice { db[:share_group_files].where(id:).update(count) }).to be_nil
  end

  it "sends none for a share group view or zip download" do
    id = db[:share_groups].insert(short_code_id: short_code("group"))
    counts = { view_count: Sequel[:view_count] + 1, zip_download_count: Sequel[:zip_download_count] + 1 }

    expect(admin_notice { db[:share_groups].where(id:).update(counts) }).to be_nil
  end

  it "sends none for a client that was used" do
    arrays = { redirect_uris: %w[https://example.com], grant_types: %w[authorization_code], response_types: %w[code] }
    client = { client_id: "client", visitor_hash: "0" * 64, **arrays.transform_values { Sequel.pg_array(it) } }
    id = db[:oauth_clients].insert(client)

    expect(admin_notice { db[:oauth_clients].where(id:).update(last_used_at: Sequel::CURRENT_TIMESTAMP) }).to be_nil
  end

  it "sends none for a new Gmail history id" do
    id = db[:mail_accounts].insert(provider: "gmail", name: "me", history_id: "1")

    expect(admin_notice { db[:mail_accounts].where(id:).update(history_id: "2") }).to be_nil
  end

  it "sends none for a commit walk that starts and ends" do
    expect(admin_notice { db[:sync_states].where(id: sync_state("backfill")).delete }).to be_nil
  end

  it "sends one for a failing sync" do
    expect(admin_notice { sync_state("failure", failure_reason: "boom", failing_since: Time.now) })
      .to eq("sync_states")
  end
end
