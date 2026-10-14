# frozen_string_literal: true

RSpec.describe Services::Operations::SaveApp, :commits do
  let(:fields) { { provider: "mastodon", host: "ruby.social", redirect_uri: "https://example.test/callback" } }

  def apps = Services::Slice["relations.service_apps"]

  def database = Services::Slice["db.rom"].gateways[:default].connection

  def save(client_id, scopes: ["read"])
    Services::Slice["operations.save_app"].call(**fields, scopes:, credentials: { "client_id" => client_id })
  end

  def saved_client_id = Services::Slice["repos.app_queries"].find("mastodon", "ruby.social").credentials[:client_id]

  def saved_while_another_insert_is_open(client_id)
    other = Sequel.connect(database.opts.merge(max_connections: 1))
    saving = other.transaction do
      other[:service_apps].insert(**fields, credentials: "sealed")
      Thread.new { save(client_id) }.tap { wait_until_waiting }
    end
    saving.join
  ensure
    other&.disconnect
  end

  def wait_until_waiting
    waiting = database[:pg_stat_activity].where(datname: Sequel.function(:current_database), wait_event_type: "Lock")
    Timeout.timeout(5) { sleep(0.01) until waiting.any? }
  end

  it "replaces the app it already holds for the server", :aggregate_failures do
    save("first")
    save("second", scopes: %w[read write])

    expect(apps.count).to eq(1)
    expect(saved_client_id).to eq("second")
    expect(apps.first[:scopes]).to eq(%w[read write])
  end

  it "keeps one app when another connect saves the same server first" do
    saved_while_another_insert_is_open("second")

    expect([apps.count, saved_client_id]).to eq([1, "second"])
  end
end
