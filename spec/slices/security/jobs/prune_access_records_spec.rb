# frozen_string_literal: true

RSpec.describe Security::Jobs::PruneAccessRecords, type: :request do
  let(:database) { Security::Slice["db.rom"].gateways[:default].connection }
  let(:day) { 24 * 60 * 60 }
  let(:keep_for) { 90 * day }

  def client = create(:oauth_client)

  def prune = described_class.new.perform

  def sight(first_seen_at:, last_seen_at:, city: "London")
    database[:sightings].insert(
      oauth_client_id: client.id, browser: "Firefox", os: "Linux", city:, country: "GB", last_address: "81.2.69.160",
      last_user_agent: "Firefox/141", first_seen_at:, last_seen_at:,
    )
  end

  def sign_in_row(created_at:, city: "London", **row)
    database[:sign_ins].insert(
      outcome: "signed_in", provider: "github", address: "81.2.69.160", user_agent: "Chrome/141", browser: "Chrome",
      os: "macOS", city:, country: "GB", created_at:, **row,
    )
  end

  it "deletes sign-ins older than 90 days and keeps the rest" do
    sign_in_row(created_at: Time.now - keep_for - 60, city: "Old")
    sign_in_row(created_at: Time.now - keep_for + 60, city: "New")

    expect { prune }.to change { database[:sign_ins].select_map(:city) }.to(["New"])
  end

  it "keeps a dismissed failure until it is 90 days old" do
    dismissed = { outcome: "denied", dismissed_at: Time.now - (20 * day) }
    sign_in_row(created_at: Time.now - keep_for - 60, city: "Old", **dismissed)
    sign_in_row(created_at: Time.now - (30 * day), city: "New", **dismissed)

    expect { prune }.to change { database[:sign_ins].select_map(:city) }.to(["New"])
  end

  it "deletes sightings last seen more than 90 days ago" do
    sight(first_seen_at: Time.now - (200 * day), last_seen_at: Time.now - keep_for - 60, city: "Old")

    expect { prune }.to change { database[:sightings].count }.to(0)
  end

  it "keeps a sighting first seen long ago but still in use" do
    sight(first_seen_at: Time.now - (200 * day), last_seen_at: Time.now - day)
    prune

    expect(database[:sightings].select_map(:city)).to eq(["London"])
  end

  it "keeps known devices and cities whatever their age" do
    database[:known_devices].insert(browser: "Chrome", os: "macOS", city: "London", country: "GB",
                                    created_at: Time.now - (400 * day))
    sign_in_row(created_at: Time.now - (400 * day))
    prune

    expect(database[:known_devices].select_map(:city)).to eq(["London"])
  end

  it "deletes a device whose last sign-in is more than 400 days old and keeps a newer one" do
    database[:devices].insert(browser: "Old", last_signed_in_at: Time.now - (401 * day))
    database[:devices].insert(browser: "New", last_signed_in_at: Time.now - (399 * day))

    expect { prune }.to change { database[:devices].select_map(:browser) }.to(["New"])
  end
end
