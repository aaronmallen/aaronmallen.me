# frozen_string_literal: true

RSpec.describe Services::Operations::ResealCredentials do
  let(:current) { "n" * 64 }
  let(:previous) { "o" * 64 }

  def apps = Services::Slice["relations.service_apps"].dataset

  def connections = Services::Slice["relations.service_connections"].dataset

  def reseal = Services::Slice["operations.reseal_credentials"].call(Services::Encryptor.new(current, previous))

  def sealed_under(key) = Services::Encryptor.new(key).seal("token")

  def store(app:, connection:)
    apps.insert(provider: "mastodon", host: "ruby.social", redirect_uri: "https://example.test/callback",
                credentials: app)
    connections.insert(provider: "linear", account_id: "a1", label: "Work", credentials: connection)
  end

  it "reseals each credential under the old key and counts them" do
    store(app: sealed_under(previous), connection: sealed_under(previous))

    expect(reseal).to eq(resealed: 2, unreadable: 0)
  end

  it "leaves every credential open to the current key alone", :aggregate_failures do
    store(app: sealed_under(previous), connection: sealed_under(current))
    reseal

    [apps, connections].each do |rows|
      expect(Services::Encryptor.new(current).open(rows.get(:credentials))).to eq("token")
    end
  end

  it "skips credentials already under the current key" do
    store(app: sealed_under(current), connection: sealed_under(current))

    expect(reseal).to eq(resealed: 0, unreadable: 0)
  end

  it "counts credentials it cannot open and leaves them be", :aggregate_failures do
    lost = sealed_under("k" * 64)
    store(app: lost, connection: sealed_under(previous))

    expect(reseal).to eq(resealed: 1, unreadable: 1)
    expect(apps.get(:credentials)).to eq(lost)
  end
end
