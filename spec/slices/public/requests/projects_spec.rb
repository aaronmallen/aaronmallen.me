# frozen_string_literal: true

RSpec.describe "Projects", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  describe "the card grid" do
    it "lists the projects by stars, most first" do
      { "few" => 2, "most" => 30, "some" => 9 }.each { |name, stars| create(:project, name:, stars:) }
      get "/projects"

      expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[most some few])
    end

    it "keeps the order they were added when the stars tie" do
      %w[first second].each { create(:project, name: it, stars: 5) }
      get "/projects"

      expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[first second])
    end

    it "leaves an archived project out of the first grid" do
      create(:project, :archived, name: "gone")
      create(:project, name: "here")
      get "/projects"

      expect(page.all(".projs:first-of-type .proj .n").map(&:text)).to eq(%w[here])
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

  describe "the past projects" do
    it "lists archived projects under their own kicker, after the active ones", :aggregate_failures do
      [[], [:archived]].each { create(:project, *it) }
      get "/projects"

      expect(page).to have_css(".projects > .projs + h2.past-title + .projs", count: 1)
      expect(page).to have_css("h2.past-title", exact_text: Public::Slice["i18n"].t("ui.views.pages.projects.past"))
    end

    it "lists them by stars, most first" do
      { "few" => 2, "most" => 30, "some" => 9 }.each { |name, stars| create(:project, :archived, name:, stars:) }
      get "/projects"

      expect(page.all(".past-title + .projs .proj .n").map(&:text)).to eq(%w[most some few])
    end

    it "leaves out a private archived project" do
      create(:project, :archived, :private, name: "hidden")
      create(:project, :archived, name: "shown")
      get "/projects"

      expect(page.all(".past-title + .projs .proj .n").map(&:text)).to eq(%w[shown])
    end

    it "renders no section when no public project is archived", :aggregate_failures do
      create(:project, name: "here")
      create(:project, :archived, :private, name: "hidden")
      get "/projects"

      expect(page).to have_no_css(".past-title")
      expect(page.all(".projs").length).to eq(1)
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

    it "renders no past projects section" do
      expect(page).to have_no_css(".past-title")
    end
  end
end
