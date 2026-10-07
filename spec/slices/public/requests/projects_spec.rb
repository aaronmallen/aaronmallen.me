# frozen_string_literal: true

RSpec.describe "Projects", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  describe "the card grid" do
    it "lists the projects in the order they were added" do
      %w[first second third].each { create(:project, name: it) }
      get "/projects"

      expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[first second third])
    end

    it "leaves out an archived project" do
      create(:project, :archived, name: "gone")
      create(:project, name: "here")
      get "/projects"

      expect(page.all(".proj .n").map(&:text)).to eq(%w[here])
    end

    it "leaves out a private project" do
      create(:project, :private, name: "hidden")
      create(:project, name: "here")
      get "/projects"

      expect(page.all(".proj .n").map(&:text)).to eq(%w[here])
    end

    it "renders the name, meta line and tagline of each card", :aggregate_failures do
      create(:project, name: "sai", tags: %w[ruby], stars: 21, release: "v1.0", tagline: "Terminal colors")
      get "/projects"

      expect(page).to have_css(".proj .n", exact_text: "sai")
      expect(page).to have_css(".proj .s", exact_text: "ruby · ★ 21 · v1.0")
      expect(page).to have_css(".proj p", exact_text: "Terminal colors")
    end

    it "links each card to its project url" do
      create(:project, url: "https://github.com/aaronmallen/sai")
      get "/projects"

      expect(page).to have_link(class: "proj", href: "https://github.com/aaronmallen/sai")
    end

    it "links a card to the project's own site rather than the repository it tracks" do
      create(:project, repo: "aaronmallen/gest", url: "https://gest.aaronmallen.dev")
      get "/projects"

      expect(page).to have_link(class: "proj", href: "https://gest.aaronmallen.dev")
    end
  end

  it "leaves the work history to the about page" do
    create(:work_entry)
    get "/projects"

    expect(page).to have_no_css(".rows")
  end

  describe "with an empty database" do
    before { get "/projects" }

    it "renders the page", :aggregate_failures do
      expect(last_response).to be_ok
      expect(page).to have_css("h1", exact_text: Public::Slice["i18n"].t("ui.views.pages.projects.heading"))
    end

    it "heads the page with a kicker over the heading, then a lede" do
      expect(page).to have_css(".projects .kicker + h1.page-title + p.lede")
    end

    it "keeps the tab title short" do
      expect(page.title).to eq("Projects | Aaron Allen")
    end

    it "renders no container for the cards" do
      expect(page).to have_no_css(".projs")
    end
  end
end
