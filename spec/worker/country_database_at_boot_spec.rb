# frozen_string_literal: true

RSpec.describe "The worker fetching the country database at boot", type: :app do
  let(:sidekiq) do
    Sidekiq::Config.new(lifecycle_events: { startup: [], exit: [] }).tap { it.logger = Logger.new(File::NULL) }
  end

  def boot
    allow(Hanami).to receive(:boot)
    allow(Sidekiq).to receive(:configure_server).and_yield(sidekiq)
    load Hanami.app.root.join("config/sidekiq.rb").to_s
    sidekiq[:lifecycle_events][:startup].each(&:call)
  end

  def queued = Analytics::Jobs::RefreshCountryDatabase.jobs

  before do
    use_country_database
    connect_maxmind_client
  end

  it "queues the refresh when the file is missing" do
    boot

    expect(queued.size).to eq(1)
  end

  it "queues nothing when the file is there" do
    write_country_database
    boot

    expect(queued).to be_empty
  end

  it "queues nothing without MaxMind credentials" do
    disconnect_maxmind_client
    boot

    expect(queued).to be_empty
  end

  context "with a path the maxmind setting names" do
    let(:shared) { country_database_root.join("shared/GeoLite2-City.mmdb") }

    before do
      maxmind = Hanami.app.settings.maxmind.merge(database_path: shared.to_s)
      allow(Hanami.app.settings).to receive(:maxmind).and_return(maxmind)
      use_country_database
    end

    it "queues the refresh when the file is missing there" do
      write_country_database
      boot

      expect(queued.size).to eq(1)
    end

    it "queues nothing when the file is there" do
      shared.dirname.mkpath
      shared.binwrite(geo_lite2_database)
      boot

      expect(queued).to be_empty
    end
  end
end
