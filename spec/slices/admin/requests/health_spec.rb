# frozen_string_literal: true

RSpec.describe "Admin health", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }

  def agents
    page.find(".card", text: "What agents see").all(".li").map { [it.find(".li-title").text, it.find(".li-sub").text] }
  end

  def at(day, hour) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour)

  def cells(row) = page.all(".health-grid-row")[row].all("a", visible: :all)

  def flagged(row) = cells(row).select { it.has_css?("i.lo", visible: :all) }.map { it[:href][/day=([\d-]+)/, 1] }

  def rows(key) = page.find(".health-day-key", text: key).sibling(".health-rows").all(".health-row").map(&:text)

  def visit_health(params = {}) = get("/admin/health", params)

  it "sends a signed out visitor to sign in" do
    visit_health

    expect(last_response).to be_redirect
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "with no span in the URL" do
      before { visit_health }

      it "says health is where you are, among the Insights tabs", :aggregate_failures do
        expect(page).to have_css("a.pill-nav-link[aria-current='page']", text: "Insights")
        expect(page.all("a.screen-tab").map(&:text)).to eq(["analytics", "activity", "health", "performance",
                                                            "time report", "search"])
        expect(page).to have_css(".screen-tab[aria-current='page']", exact_text: "health")
      end

      it "offers 14, 30 and 90 day spans and marks 30 current", :aggregate_failures do
        expect(page.all(".health-bar .seg-option").map(&:text)).to eq(%w[14d 30d 90d])
        expect(page).to have_css(".seg-option.current[aria-current='page']", text: "30d")
      end

      it "draws one column a day for 30 days" do
        expect(cells(0).size).to eq(30)
      end

      it "opens on today with no next day", :aggregate_failures do
        expect(page).to have_css(".health-day-title", text: "Today")
        expect(page).to have_css(".health-day-head span.seg-option[aria-disabled]", text: "Next day")
      end

      it "says the patterns need more days" do
        expect(page.find(".card", text: "Patterns")).to have_css(".empty", text: "Not enough days")
      end

      it "says no client or token holds health" do
        expect(page.find(".card", text: "What agents see")).to have_css(".empty", text: "holds health")
      end
    end

    {
      "14" => 14, "90" => 90, "7" => 30,
    }.each do |span, columns|
      it "draws #{columns} columns for span #{span}" do
        visit_health(span:)

        expect(cells(0).size).to eq(columns)
      end
    end

    describe "a range with flagged days" do
      let(:short) { today - 1 }
      let(:low_hrv) { today - 2 }
      let(:high_resting) { today - 3 }

      before do
        (1..10).each do |back|
          day = today - back
          create(
            :health_day,
            day:, minutes_asleep: day == short ? 300 : 420, hrv: day == low_hrv ? 40 : 50,
            resting_heart_rate: day == high_resting ? 60 : 55, steps: 8421, active_zone_minutes: 22,
            bed_at: at(day - 1, 23), woke_at: at(day, 6),
          )
        end
        create(:commit, commit_date: short, commit_time: "22:30")
        visit_health
      end

      it "flags the short night, the low HRV and the raised resting heart rate", :aggregate_failures do
        expect(flagged(0)).to eq([short.iso8601])
        expect(flagged(1)).to eq([low_hrv.iso8601])
        expect(flagged(2)).to eq([high_resting.iso8601])
      end

      it "flags late commits" do
        expect(flagged(6)).to eq([short.iso8601])
      end

      it "states the resting heart rate pattern" do
        expect(page.find(".health-pattern")).to have_text(/averaged 55\.8 bpm over the last week, against 55 bpm/)
      end
    end

    describe "the hints" do
      let(:days) { (1..10).to_h { [it, today - it] } }
      let(:edges) do
        { minutes_asleep: { 1 => 359, 2 => 360 }, hrv: { 3 => 40, 4 => 44 }, resting_heart_rate: { 5 => 60, 6 => 57 } }
      end
      let(:usual) { { minutes_asleep: 420, hrv: 50, resting_heart_rate: 55 } }

      def health_token
        client = Spec::DB::Factories[:mcp].create(:oauth_client)
        mcp_connect(client, verifier: Blog::Types::NewSecret[], scope: "health").fetch("access_token")
      end

      def hint(key) = Admin::Slice["i18n"].t(key, scope: "ui")

      def readings(back) = usual.to_h { |field, value| [field, edges.fetch(field).fetch(back, value)] }

      def tool_patterns
        params = { name: "read_health_days", arguments: { from: (today - 29).iso8601, to: today.iso8601 } }
        headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{health_token}" }
        post "/mcp", JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/call", params: }), headers
        JSON.parse(JSON.parse(last_response.body).dig("result", "content", 0, "text")).fetch("patterns")
      end

      before do
        days.each do |back, day|
          create(:health_day, day:, **readings(back), steps: 8421, active_zone_minutes: 22, bed_at: at(day - 1, 23),
                              woke_at: at(day, 6))
        end
        create(:commit, commit_date: days[7], commit_time: "22:00")
        create(:commit, commit_date: days[8], commit_time: "21:59")
        visit_health
      end

      it "flags each day past a line the bar's hint names, and none short of it", :aggregate_failures do
        expect([0, 1, 2, 6].map { flagged(it) }).to eq([1, 3, 5, 7].map { [days[it].iso8601] })
        expect(cells(0).size).to eq(30)
        expect(page.find(".health-bar .hint").text).to eq(hint("views.health.show.hint"))
      end

      it "gives agents with health the averages the patterns card shows for the same days", :aggregate_failures do
        card = page.find(".card", text: "Patterns")
        shown = card.find(".health-pattern", text: "bpm").text.scan(/[\d.]+(?= bpm)/).map(&:to_f)
        rest = tool_patterns.fetch("resting_heart_rate")

        expect(shown).to eq(%w[subject rest].map { rest.dig(it, "averages", "resting_heart_rate") })
        expect(card.find(".hint").text).to eq(hint("components.health.patterns_card.hint"))
      end
    end

    describe "a day's detail" do
      let(:day) { today - 4 }
      let(:body) do
        [
          "Asleep 23:00 → 04:005h 00m", "HRV · 30-day 4848 ms", "Resting heart rate · 30-day 5454 bpm",
          "Steps · zone minutes8,421 · 22",
        ]
      end

      before do
        create(
          :health_day,
          day:, minutes_asleep: 300, hrv: 48.4, resting_heart_rate: 54, steps: 8421, active_zone_minutes: 22,
          bed_at: at(day - 1, 23), woke_at: at(day, 4),
        )
        create(
          :workout,
          kind: "RUNNING", started_at: at(day, 7), minutes: 30, distance_meters: 5000, average_heart_rate: 150,
          kcal: 330, device: "Pixel Watch 3",
        )
        create(:commit, commit_date: day, commit_time: "22:15")
        create(:task, :done, completed_at: at(day, 15))
        visit_health(span: 14, day: day.iso8601)
      end

      it "titles the day by how long ago it was" do
        expect(page).to have_css(".health-day-title", text: "4 days ago")
      end

      it "shows the day's health against its 30-day baseline", :aggregate_failures do
        expect(rows("Body")).to eq(body)
        expect(page).to have_css(".health-row-value.lo", text: "5h 00m")
      end

      it "shows the day's workouts" do
        expect(page.find(".health-workout")).to have_text(
          "Running · 5 km30m · avg 150 bpm · 330 kcal · Pixel Watch 307:00",
        )
      end

      it "shows the day's work", :aggregate_failures do
        expect(rows("Work")).to eq(["Focused time0m", "Commits1", "Commits after 22:001", "Tasks done1"])
        expect(page).to have_link("This day in activity", href: "/admin/activity?day=#{day.iso8601}")
      end

      it "links the previous and next days", :aggregate_failures do
        expect(page).to have_css("a[rel='prev'][href='/admin/health?span=14&day=#{(day - 1).iso8601}']")
        expect(page).to have_css("a[rel='next'][href='/admin/health?span=14&day=#{(day + 1).iso8601}']")
      end

      it "marks the day in the grid" do
        expect(page.first(".health-grid-row").find("a.on", visible: :all)[:href]).to include(day.iso8601)
      end
    end

    it "stops at the first day of the span" do
      visit_health(span: 14, day: (today - 13).iso8601)

      expect(page).to have_css(".health-day-head span.seg-option[aria-disabled]", text: "Previous day")
    end

    it "opens on today when the day sits outside the span" do
      visit_health(span: 14, day: (today - 20).iso8601)

      expect(page).to have_css(".health-day-title", text: "Today")
    end

    describe "the agents card" do
      def client(name, scopes, **)
        create(:oauth_token, scopes:, oauth_client: create(:oauth_client, client_name: name), **)
      end

      def mint(name, scopes) = API::Slice["operations.mint_token"].call(name:, scopes:)

      before do
        client("Claude", %w[read health])
        client("Reader", %w[read])
        client("Gone", %w[read health], revoked_at: Time.now)
        mint("Terminal", %w[read health])
        mint("Script", %w[read])
        visit_health
      end

      it "lists the clients and tokens that hold health" do
        expect(agents).to eq([["Claude", "MCP client"], ["Terminal", "API token"]])
      end
    end
  end
end
