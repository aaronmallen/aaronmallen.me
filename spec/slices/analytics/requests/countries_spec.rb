# frozen_string_literal: true

RSpec.describe "Country lookup", type: :request do
  let(:agent) { "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:event_repo) { Analytics::Slice["repos.analytics_event_repo"] }

  before { use_country_database }

  def country_of(address)
    visit = { kind: "view", path: "/writing/hello", title: "Hello" }.to_json
    post "/pulse", visit, "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent, "REMOTE_ADDR" => address

    event_repo.analytics_events.order(:id).to_a.last&.country_code
  end

  describe "a view" do
    before { write_country_database }

    it "stores the country of an address the database holds" do
      expect(country_of("1.2.3.4")).to eq("US")
    end

    it "reads the network the address falls in" do
      expect(country_of("81.2.69.160")).to eq("GB")
    end

    it "reads an IPv6 address" do
      expect(country_of("2001:db8::1")).to eq("DE")
    end

    it "leaves the country unknown for an address the database doesn't hold" do
      expect(country_of("8.8.8.8")).to be_nil
    end

    it "leaves the country unknown for a private address" do
      expect(country_of("10.0.0.1")).to be_nil
    end

    it "keeps reading the database it opened for the next view" do
      country_of("1.2.3.4")

      expect(country_of("81.2.69.160")).to eq("GB")
    end

    it "reads a database that replaced the one it had open" do
      country_of("1.2.3.4")
      write_country_database(geo_lite2_database({ "1.2.3.0/24" => "CA" }))

      expect(country_of("1.2.3.5")).to eq("CA")
    end
  end

  describe "a view the lookup can't place" do
    it "is stored with no country when no database is on disk" do
      expect(country_of("1.2.3.4")).to be_nil
    end

    it "is stored with no country when the file on disk isn't a database" do
      write_country_database("not a database")

      expect(country_of("1.2.3.4")).to be_nil
    end

    describe "with the database directory unreadable" do
      before do
        write_country_database
        country_database_path.dirname.chmod(0o000)
      end

      after { country_database_path.dirname.chmod(0o700) }

      it "is stored with no country" do
        expect(country_of("1.2.3.4")).to be_nil
      end

      it "is still accepted" do
        country_of("1.2.3.4")

        expect(last_response.status).to eq(202)
      end
    end
  end

  describe "the Today page" do
    let(:page) { Capybara.string(last_response.body) }

    before do
      sign_in_to_admin
      connect_maxmind_client
    end

    def failure_lines
      get "/admin"

      page.all(".sync-failures .sync-failure").map(&:text)
    end

    it "says the database is gone rather than leaving every visitor unknown" do
      expect(failure_lines).to eq(["Country lookup · No database on disk"])
    end

    it "says the database won't open when the file isn't one" do
      write_country_database("not a database")

      expect(failure_lines).to eq(["Country lookup · The database won't open"])
    end

    it "says the database won't open when its directory can't be read" do
      write_country_database
      country_database_path.dirname.chmod(0o000)

      expect(failure_lines).to eq(["Country lookup · The database won't open"])
    ensure
      country_database_path.dirname.chmod(0o700)
    end

    it "says nothing while the database reads" do
      write_country_database

      expect(failure_lines).to be_empty
    end

    it "says nothing with no MaxMind key, the way ADR 0045 allows" do
      disconnect_maxmind_client

      expect(failure_lines).to be_empty
    end
  end
end
