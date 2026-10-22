# frozen_string_literal: true

RSpec.describe "Sightings keyed on the user agent product", type: :app do
  let(:gateway) { Hanami.app["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:client) { create(:oauth_client).id }
  let(:hour) { 60 * 60 }

  let(:migration) do
    ROM::SQL.with_gateway(gateway) { load "config/db/migrate/20261022140000_key_sightings_on_product.rb" }
    Sequel::Migration.descendants.pop
  end

  def merged = { city: "Leeds", last_address: "81.2.69.161", calls: 5, product: "claude-code" }

  def rows = db[:sightings].order(:id).select(:city, :last_address, :calls, :product).all

  def sight(city, address, seen, user_agent: "claude-code/1.2", calls: 2)
    db[:sightings].insert(
      oauth_client_id: client, city:, country: "GB", calls:, last_address: address, last_user_agent: user_agent,
      first_seen_at: Time.now - seen - hour, last_seen_at: Time.now - seen,
    )
  end

  before do
    migration.apply(db, :down)
    sight("London", "81.2.69.160", 2 * hour)
    sight("Leeds", "81.2.69.161", hour, user_agent: "claude-code/1.3", calls: 3)
    sight("York", "81.2.69.162", 3 * hour, user_agent: "python-httpx/0.27")
    migration.apply(db, :up)
  end

  it "merges one client's rows split by city into its latest city and address" do
    expect(rows).to eq([merged, { city: "York", last_address: "81.2.69.162", calls: 2, product: "python-httpx" }])
  end

  it "keeps the first time it saw any of the merged rows" do
    expect(db[:sightings].where(product: "claude-code").get(:first_seen_at)).to be_within(5).of(Time.now - (3 * hour))
  end
end
