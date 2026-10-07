# frozen_string_literal: true

require "base64"

RSpec.describe Analytics::Jobs::RefreshCountryDatabase do
  let(:database) { geo_lite2_database }
  let(:mirror) { "https://mm-prod-geoip-databases.example.com/GeoLite2-City.tar.gz" }

  def credentials = "Basic #{Base64.strict_encode64('123456:license')}"

  before do
    use_country_database
    connect_maxmind_client
    stub_maxmind_download(body: geo_lite2_archive(database))
  end

  def download = a_request(:get, GeoLite2Database::DOWNLOAD_URL).with(query: hash_including({}))

  def failure = sync_state_queries.failure(Blog::Types::SyncName["country_database"])

  def lookup(address) = Analytics::Slice["geo.countries"].code(address)

  def refresh = described_class.new.perform

  def refresh_failing
    refresh
  rescue described_class::RefreshFailed
    nil
  end

  def stored = country_database_path.binread

  def sync_state_queries = Record::Slice["repos.sync_state_queries"]

  describe "a refresh MaxMind answers" do
    it "writes the database inside the archive" do
      refresh

      expect(stored).to eq(database)
    end

    it "leaves the lookup reading the fresh database" do
      refresh

      expect(lookup("1.2.3.4")).to eq("US")
    end

    it "replaces a database the lookup already had open" do
      write_country_database(geo_lite2_database({ "1.2.3.0/24" => "CA" }))
      lookup("1.2.3.4")
      refresh

      expect(lookup("1.2.3.4")).to eq("US")
    end

    it "sends the account and the key as basic authentication" do
      refresh

      expect(download.with(headers: { "Authorization" => credentials })).to have_been_made
    end

    it "follows the redirect MaxMind answers with" do
      stub_maxmind_download(status: 302, headers: { "Location" => mirror })
      stub_request(:get, mirror).to_return(body: geo_lite2_archive(database))
      refresh

      expect(stored).to eq(database)
    end

    it "keeps the credentials off the host the redirect names" do
      stub_maxmind_download(status: 302, headers: { "Location" => mirror })
      stub_request(:get, mirror).to_return(body: geo_lite2_archive(database))
      refresh

      expect(a_request(:get, mirror).with(headers: { "Authorization" => credentials })).not_to have_been_made
    end

    it "clears the failure an earlier refresh left" do
      stub_maxmind_download(status: 401, body: "")
      refresh_failing
      stub_maxmind_download(body: geo_lite2_archive(database))
      refresh

      expect(failure).to be_nil
    end
  end

  describe "with no MaxMind key, the way ADR 0045 allows" do
    before { disconnect_maxmind_client }

    it "stays quiet" do
      expect { refresh }.not_to raise_error
    end

    it "asks MaxMind for nothing" do
      refresh

      expect(download).not_to have_been_made
    end

    it "leaves no failure to read" do
      refresh

      expect(failure).to be_nil
    end

    it "stays quiet with only an account set" do
      connect_maxmind_client(license_key: nil)

      expect { refresh }.not_to raise_error
    end

    it "stays quiet with only a key set" do
      connect_maxmind_client(account_id: nil)
      refresh

      expect(download).not_to have_been_made
    end
  end

  describe "a download that fails" do
    it "fails the run with the reason MaxMind gave" do
      stub_maxmind_download(status: 401, body: "")

      expect { refresh }
        .to raise_error(described_class::RefreshFailed, "download_failed: MaxMind answered 401 for GeoLite2-City")
    end

    it "leaves a dead key where the operator reads it, message and all" do
      stub_maxmind_download(status: 401, body: "")
      refresh_failing

      expect(failure).to include(message: "MaxMind answered 401 for GeoLite2-City", reason: "download_failed")
    end

    it "asks MaxMind once, rather than holding a worker through the retries" do
      stub_maxmind_download(status: 503, body: "")
      refresh_failing

      expect(download).to have_been_made.once
    end

    it "says the download failed when it never arrives" do
      stub_request(:get, GeoLite2Database::DOWNLOAD_URL).with(query: hash_including({})).to_timeout
      refresh_failing

      expect(failure).to include(message: a_string_including("GeoLite2-City download failed"))
    end

    it "keeps the copy it had" do
      write_country_database
      stub_maxmind_download(status: 401, body: "")
      refresh_failing

      expect(stored).to eq(database)
    end
  end

  describe "an archive that won't unpack" do
    {
      "cut short" => -> { geo_lite2_archive(geo_lite2_database).byteslice(0, 50) },
      "not an archive" => -> { "not an archive" },
    }.each do |name, archive|
      it "fails the run on an archive #{name}" do
        stub_maxmind_download(body: instance_exec(&archive))
        refresh_failing

        expect(failure).to include(message: a_string_including("archive is unreadable"), reason: "download_failed")
      end
    end

    it "fails the run on an archive that holds no database" do
      stub_maxmind_download(body: geo_lite2_archive(database, name: "GeoLite2-City_20260928/COPYRIGHT.txt"))
      refresh_failing

      expect(failure).to include(message: a_string_including("holds no database"), reason: "download_failed")
    end
  end

  describe "a download that isn't a database" do
    before { stub_maxmind_download(body: geo_lite2_archive("not a database")) }

    it "fails the run with the reason the lookup gave" do
      refresh_failing

      expect(failure).to include(message: a_string_including("not a MaxMind database"), reason: "invalid_database")
    end

    it "keeps the copy it had" do
      write_country_database
      refresh_failing

      expect(stored).to eq(database)
    end

    it "leaves no half-written file behind" do
      refresh_failing

      expect(country_database_path.dirname.children).to be_empty
    end
  end

  describe "a database directory that can't be written" do
    before do
      write_country_database
      stub_maxmind_download(body: geo_lite2_archive(geo_lite2_database({ "1.2.3.0/24" => "CA" })))
      country_database_path.dirname.chmod(0o500)
    end

    after { country_database_path.dirname.chmod(0o700) }

    it "leaves the failure where the operator reads it" do
      refresh_failing

      expect(failure).to include(message: a_string_including("Permission denied"), reason: "write_failed")
    end

    it "keeps the copy it had" do
      refresh_failing

      expect(stored).to eq(database)
    end
  end
end
