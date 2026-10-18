# frozen_string_literal: true

RSpec.describe "Admin jobs", type: :feature do
  def box(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")

  before do
    worker = Sidekiq::Process.new(
      "identity" => "w", "hostname" => "a-long-worker-host-name.example.internal", "pid" => 4_120,
      "started_at" => Time.now.to_f, "queues" => %w[default mailers], "busy" => 10, "concurrency" => 10,
      "beat" => Time.now.to_f, "quiet" => "false",
    )
    payload = { "class" => "Social::Jobs::SendWebmention", "args" => ["https://example.org/#{'a' * 200}"] }
    work = Sidekiq::Work.new("w", "t", "queue" => "default", "run_at" => Time.now.to_i - 90, "payload" => payload)
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([worker])
    allow(Sidekiq::WorkSet).to receive(:new).and_return([["w", "t", work]])
    failed = payload.merge(
      "jid" => "abc123", "queue" => "default", "retry_count" => 3, "error_class" => "Net::OpenTimeout",
      "error_message" => "Failed to open TCP connection to #{'b' * 200}",
    )
    queue = Sidekiq::Stats::QueueSummary.new(name: "default", size: 1_820_000, latency: 90.0, paused: false)
    replace_component("sidekiq.set_jobs", ->(*, **) { [Sidekiq::SortedEntry.new(nil, Time.now.to_f, failed.to_json)] })
    allow(Sidekiq::Stats).to receive(:new)
      .and_return(Spec::FakeStats.new(enqueued: 1_820_000, retry_size: 342, dead_size: 57, scheduled_size: 140,
                                      queue_summaries: [queue]))
    sign_in_to_admin
  end

  it "fits a phone, with the bars below today's figures", :aggregate_failures do
    page.current_window.resize_to(375, 800)
    visit "/admin/settings/jobs"

    %w[.jobs-health .jobs-args .jobs-queue-size .jobs-error].each { expect(page).to have_css(it) }
    expect(evaluate_script("document.documentElement.scrollWidth - innerWidth")).to be <= 0
    expect(box(".jobs-bars")["top"]).to be >= box(".jobs-big-small")["bottom"]
  end

  it "keeps the bars beside today's figures on a wide screen" do
    page.current_window.resize_to(1180, 800)
    visit "/admin/settings/jobs"

    expect(box(".jobs-bars")["top"]).to be < box(".jobs-big-small")["bottom"]
  end

  describe "the More button" do
    def box_of(node) = node.evaluate_script("this.getBoundingClientRect().toJSON()")

    def click_more(within)
      more(within).tap do |button|
        button.hover
        button.click
        menu
      end
    end

    def first_item? = first("[data-context-menu] [data-context-item]").matches_css?(":focus")

    def more(within) = first(within).find("[data-menu-more]", visible: :all)

    def open_by_key(within, key)
      execute_script("arguments[0].focus({ preventScroll: true })", more(within))
      press(key)
    end

    before do
      retries = Spec::FakeJobSet.new("retry").tap do |set|
        set.add(Time.now, { "class" => "Social::Jobs::CrossPost", "args" => [42], "jid" => "abc123",
                            "queue" => "default", "error_class" => "Net::OpenTimeout" })
      end
      allow(Sidekiq::RetrySet).to receive(:new).and_return(retries)
      page.current_window.resize_to(1180, 800)
      visit "/admin/settings/jobs"
    end

    it "opens a set job's menu below the button" do
      button = click_more("#jobs-retries .li")

      expect(box("[data-context-menu]")["top"] - box_of(button)["bottom"]).to be_between(0, 8)
    end

    it "marks the button expanded while its menu is open", :aggregate_failures do
      button = click_more("#jobs-retries .li")
      expect(button["aria-expanded"]).to eq("true")

      press(:escape)
      expect(page).to have_no_css("[data-context-menu]")
      expect(button["aria-expanded"]).to eq("false")
    end

    it "leaves the job drawer shut", :aggregate_failures do
      click_more("#jobs-retries .li")

      expect(menu).to have_css(".ctx-item")
      expect(page).to have_current_path("/admin/settings/jobs")
      expect(page).to have_no_css("dialog[open]")
    end

    it "opens a cron entry's menu" do
      click_more(".jobs-cron-entry")

      expect(menu).to have_css(".ctx-item")
    end

    it "names the button for screen readers" do
      expect(more("#jobs-retries .li")["aria-label"]).to eq("More actions for Social::Jobs::SendWebmention")
    end

    it "puts focus on the first item when Enter opens it", :aggregate_failures do
      open_by_key("#jobs-retries .li", :enter)

      expect(page).to have_css("[data-context-menu] [data-context-item]:focus")
      expect(first_item?).to be(true)
    end

    it "puts focus on the first item when Space opens it", :aggregate_failures do
      open_by_key("#jobs-retries .li", :space)

      expect(page).to have_css("[data-context-menu] [data-context-item]:focus")
      expect(first_item?).to be(true)
    end
  end
end
