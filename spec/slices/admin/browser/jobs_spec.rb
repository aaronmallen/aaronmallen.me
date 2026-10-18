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
    queue = Spec::FakeQueue.new(name: "default", size: 1_820_000, latency: 90.0)
    allow(Sidekiq::Queue).to receive(:all).and_return([queue])
    allow(Sidekiq::Stats).to receive(:new)
      .and_return(Spec::FakeStats.new(enqueued: 1_820_000, retry_size: 342, dead_size: 57, scheduled_size: 140))
    sign_in_to_admin
  end

  it "fits a phone, with the bars below today's figures", :aggregate_failures do
    page.current_window.resize_to(375, 800)
    visit "/admin/settings/jobs"

    expect(page).to have_css(".jobs-health").and have_css(".jobs-args").and have_css(".jobs-queue-size")
    expect(evaluate_script("document.documentElement.scrollWidth - innerWidth")).to be <= 0
    expect(box(".jobs-bars")["top"]).to be >= box(".jobs-big-small")["bottom"]
  end

  it "keeps the bars beside today's figures on a wide screen" do
    page.current_window.resize_to(1180, 800)
    visit "/admin/settings/jobs"

    expect(box(".jobs-bars")["top"]).to be < box(".jobs-big-small")["bottom"]
  end
end
