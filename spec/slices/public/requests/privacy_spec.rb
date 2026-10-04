# frozen_string_literal: true

RSpec.describe "Privacy", type: :request do
  let(:i18n) { Public::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:view) { Public::UI::Views::Pages::Privacy }

  before { get "/privacy" }

  def copy(key) = i18n.t(key, scope: "ui.views.pages.privacy")

  def list_after(heading) = page.find(".privacy h2", exact_text: heading).find(:xpath, "following-sibling::ul[1]")

  it "titles the page" do
    expect(page.title).to eq("Privacy | Aaron Allen")
  end

  it "heads the page with a kicker, a heading and a lede", :aggregate_failures do
    expect(page).to have_css(".privacy .kicker", exact_text: copy("kicker"))
    expect(page).to have_css(".privacy h1.page-title", exact_text: copy("heading"))
    expect(page).to have_css(".privacy p.lede", exact_text: copy("lede"))
  end

  it "gives each topic a heading, in order, and ends with requests" do
    expect(page.all(".privacy .post-body h2").map(&:text))
      .to eq([*view::SECTIONS.keys.map { copy("#{it}.heading") }, copy("requests.heading")])
  end

  it "says the only cookie is the theme, for a year" do
    expect(page).to have_css(".privacy .post-body p", exact_text: copy("cookies.theme"))
  end

  it "names each hash it keeps" do
    expect(list_after(copy("hashes.heading"))).to have_css("li", count: view::SECTIONS.dig(:hashes, :items).size)
  end

  it "says how long each thing stays", :aggregate_failures do
    retention = list_after(copy("retention.heading"))

    expect(retention).to have_css("li", text: "90 days", count: 2)
    expect(retention).to have_css("li", text: "12 months old")
    expect(retention).to have_css("li", text: "for good")
  end

  it "matches the windows the analytics enforce", :aggregate_failures do
    expect(page.text).to include("#{Analytics::Operations::PruneAnalyticsEvents::RETENTION_DAYS} days")
    expect(page.text).to include("#{Analytics::Readers::MONTHS} months")
    expect(page.text).to include("#{Analytics::ReadThrough::READ_SECONDS} seconds")
    expect(page.text).to include("#{Analytics::Operations::RecordVisit::MAX_READ_SECONDS / 60} minutes")
  end

  it "points requests to the contact form" do
    paragraph = page.find(".privacy .post-body p", text: copy("requests.body"))

    expect(paragraph).to have_link(copy("requests.link"), href: "/contact", exact: true)
  end

  it "publishes no address to write to" do
    expect(last_response.body).not_to include("mailto:")
  end
end
