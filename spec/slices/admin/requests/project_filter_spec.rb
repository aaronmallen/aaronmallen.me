# frozen_string_literal: true

RSpec.describe "Admin project filter bar", type: :request do
  let(:project) { create(:project, name: "Podcast", key: "POD") }

  def choices = JSON.parse(page.find("[data-task-filter]")["data-task-filter"])

  def meta = page.find(".task-filter-meta")

  before do
    sign_in_to_admin
    create(:task, title: "Record the intro", project_id: project.id, tags: %w[audio])
    create(:task, title: "Book a guest", project_id: project.id, tags: %w[guests], status: "in_progress")
  end

  it "shows no match line without a query" do
    get "/admin/projects/#{project.id}"

    expect(page).to have_no_css(".task-filter-meta")
  end

  it "keeps the query in the field" do
    get "/admin/projects/#{project.id}?q=label:audio"

    expect(page).to have_field("q", with: "label:audio")
  end

  it "filters the board and the list by the query", :aggregate_failures do
    get "/admin/projects/#{project.id}?q=label:audio"

    expect(page.all(".kb .kc", visible: :all).map(&:text)).to all(include("Record the intro"))
    expect(page.all(".kb .kc", visible: :all).size).to eq(1)
    expect(page.all(".kb-list .kli", visible: :all).size).to eq(1)
  end

  it "filters by state and words" do
    get "/admin/projects/#{project.id}?q=is:doing+guest"

    expect(page.all(".kb .kc", visible: :all).map(&:text)).to contain_exactly(include("Book a guest"))
  end

  it "counts the matches against every task on the board" do
    get "/admin/projects/#{project.id}?q=-label:audio"

    expect(meta).to have_text("1 of 2 tasks match")
  end

  it "shows the terms it ignored" do
    get "/admin/projects/#{project.id}?q=author:me+is:soon+is:open"

    expect(meta.find(".task-filter-ignored")).to have_text("ignored author:me is:soon")
  end

  it "clears the filter back to the bare board", :aggregate_failures do
    get "/admin/projects/#{project.id}?q=label:audio"

    expect(meta).to have_link("clear filter", href: "/admin/projects/#{project.id}")
    expect(page).to have_link("Clear filter", href: "/admin/projects/#{project.id}")
  end

  it "keeps the query in the view links and the move return path", :aggregate_failures do
    get "/admin/projects/#{project.id}?q=label:audio"

    expect(page).to have_link(href: "/admin/projects/#{project.id}?q=label:audio&view=list")
    expect(page.first("input[name=return_to]",
                      visible: :all).value).to eq("/admin/projects/#{project.id}?q=label:audio")
  end

  it "keeps the query when it loads more" do
    20.times { create(:task, project_id: project.id, tags: %w[audio]) }
    get "/admin/projects/#{project.id}?q=label:audio"

    expect(page.first("form:has(button.bt.gh) input[name=q]", visible: :all).value).to eq("label:audio")
  end

  it "suggests the qualifiers, the project's tags and the columns", :aggregate_failures do
    create(:tag, :private, name: "home")
    get "/admin/projects/#{project.id}"

    expect(choices.fetch("qualifiers").map(&:first)).to include("label:", "-label:", "no:label", "column:")
    expect(choices.fetch("tags").map(&:first)).to eq(%w[audio guests])
    expect(choices.fetch("columns")).to include(["in_progress", "in progress"])
  end

  it "puts the project tags button beside the bar" do
    get "/admin/projects/#{project.id}"

    expect(page).to have_css(".task-filter-row > button", text: "Tags")
  end
end
