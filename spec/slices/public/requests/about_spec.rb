# frozen_string_literal: true

RSpec.describe "About", type: :request do
  let(:i18n) { Public::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }

  before { get "/about" }

  def copy(key) = i18n.t(key, scope: "ui.views.pages.about")

  def settings = Hanami.app.settings

  it "titles the page" do
    expect(page.title).to eq("About | Aaron Allen")
  end

  it "heads the page with a kicker over the heading", :aggregate_failures do
    expect(page).to have_css(".about .kicker", exact_text: copy("kicker"))
    expect(page).to have_css(".about h1.page-title", exact_text: copy("heading"))
  end

  it "opens with a lede" do
    expect(page).to have_css(".about p.lede", exact_text: copy("lede"))
  end

  it "puts the prose in the same body as an article" do
    expect(page).to have_css(".about .post-body h2", exact_text: copy("prose.open_source.heading"))
  end

  it "speaks of a domain-driven focus", :aggregate_failures do
    expect(page).to have_css(".about .post-body p", exact_text: copy("prose.work"))
    expect(page).to have_css(".about .post-body p", exact_text: copy("prose.structure"))
  end

  it "points the Rust paragraph at the projects page for the full list" do
    paragraph = page.find(".about .post-body p", text: copy("prose.open_source.rust"))

    expect(paragraph).to have_link(copy("prose.open_source.projects_link"), href: "/projects", exact: true)
  end

  it "points the Ruby paragraph at the Hanakai team" do
    paragraph = page.find(".about .post-body p", text: copy("prose.open_source.ruby"))

    expect(paragraph).to have_link(copy("prose.open_source.hanakai_link"), href: "https://hanakai.org", exact: true)
  end

  it "names none of the work or hobbies left behind" do
    retired = /Root Insurance|Commands and Queries|activeinteractor|domainic|\bsai\b|farg|overlanding/i

    expect(page.text).not_to match(retired)
  end

  it "lists what happens away from the keyboard" do
    expect(page.all(".about .post-body ul li strong").map(&:text))
      .to eq(Public::UI::Views::Pages::About::HOBBIES.map { copy(it.first.delete_prefix(".")) })
  end

  it "leaves out the career heading while there is no history" do
    expect(page).to have_no_css(".about .rows")
  end

  describe "the career history" do
    before do
      create(:work_entry, role: "Second", position: 2)
      create(:work_entry, role: "First", position: 1)
      get "/about"
    end

    it "renders the rows in position order under the career heading", :aggregate_failures do
      expect(page).to have_css(".about h2.work-title", exact_text: copy("career"))
      expect(page.all(".about .rows .row h3").map(&:text)).to eq(%w[First Second])
    end

    it "puts the rows after the prose and before the call to action" do
      expect(page.all(".about > .post-body, .about > .rows, .about > .cta").map { it[:class] })
        .to eq(%w[post-body rows cta])
    end
  end

  describe "a career row" do
    def row(*traits, **attrs)
      create(:work_entry, *traits, **attrs)
      get "/about"
      page.find(".about .rows .row")
    end

    it "shows the years, the role, the organization and the blurb" do
      expect(row(org: "Rackspace", role: "Software Engineer", blurb: "Built things", from_year: 2018, to_year: 2021))
        .to have_css(".yr", exact_text: "2018–2021")
        .and have_css("h3", exact_text: "Software Engineer")
        .and have_css(".at", exact_text: "Rackspace")
        .and have_css("p", exact_text: "Built things")
    end

    it "names the open end of a current role" do
      expect(row(:current, from_year: 2021)).to have_css(".yr", exact_text: "2021–Present")
    end

    it "leaves the blurb out when it is blank" do
      expect(row(blurb: " ")).to have_no_css("p")
    end
  end

  it "closes with the contact form and the profiles the settings hold" do
    profiles = %i[github mastodon bluesky].map { settings.public_send(it)[:profile_url] }

    expect(page.all(".about .cta .links a").map { it[:href] }).to eq(["/contact", *profiles])
  end

  it "publishes no address to write to" do
    expect(last_response.body).not_to include("mailto:")
  end
end
