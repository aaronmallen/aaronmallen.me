# frozen_string_literal: true

RSpec.describe "Admin project filter bar", type: :feature do
  let(:project) { create(:project, name: "Podcast", key: "POD") }

  def field = find_field("q")

  def suggestions = all("#task-filter-list [role=option]").map(&:text)

  before do
    sign_in_to_admin
    create(:task, title: "Record the intro", project_id: project.id, tags: %w[audio])
    create(:task, title: "Book a guest", project_id: project.id, tags: %w[guests])
    visit "/admin/projects/#{project.id}"
  end

  it "suggests the qualifiers when it takes focus" do
    field.click

    expect(suggestions).to include(a_string_starting_with("label:"), a_string_starting_with("is:open"))
  end

  it "suggests the project's tags after label:" do
    field.send_keys("label:gu")

    expect(suggestions).to eq(["#guests"])
  end

  it "suggests the columns after column:" do
    field.send_keys("column:re")

    expect(suggestions).to contain_exactly(a_string_starting_with("column:ready"))
  end

  it "filters the board in place when it picks a tag, and keeps the query on reload", :aggregate_failures do
    field.send_keys("label:aud", :enter)

    expect(page).to have_css(".task-filter-meta", text: "1 of 2 tasks match")
    expect(page).to have_current_path("/admin/projects/#{project.id}?q=label%3Aaudio+")
    refresh
    expect(page).to have_field("q", with: "label:audio")
  end

  it "picks a suggestion with the arrow keys" do
    field.send_keys("is:do", :down, :enter)

    expect(page).to have_css(".task-filter-meta", text: "0 of 2 tasks match")
  end
end
