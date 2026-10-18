# frozen_string_literal: true

RSpec.describe "Admin jobs", type: :feature do
  def box(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")

  before do
    worker = Sidekiq::Process.new("busy" => 10, "concurrency" => 10, "beat" => Time.now.to_f, "quiet" => "false")
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([worker])
    allow(Sidekiq::Stats).to receive(:new)
      .and_return(Spec::FakeStats.new(enqueued: 1_820_000, retry_size: 342, dead_size: 57, scheduled_size: 140))
    sign_in_to_admin
  end

  it "fits a phone, with the bars below today's figures", :aggregate_failures do
    page.current_window.resize_to(375, 800)
    visit "/admin/settings/jobs"

    expect(page).to have_css(".jobs-health")
    expect(evaluate_script("document.documentElement.scrollWidth - innerWidth")).to be <= 0
    expect(box(".jobs-bars")["top"]).to be >= box(".jobs-big-small")["bottom"]
  end

  it "keeps the bars beside today's figures on a wide screen" do
    page.current_window.resize_to(1180, 800)
    visit "/admin/settings/jobs"

    expect(box(".jobs-bars")["top"]).to be < box(".jobs-big-small")["bottom"]
  end
end
