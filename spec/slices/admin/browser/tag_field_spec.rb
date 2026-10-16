# frozen_string_literal: true

RSpec.describe "Admin tag field", type: :feature do
  let(:posts) { Posts::Slice["repos.post_queries"] }
  let(:projects) { Projects::Slice["repos.project_queries"] }
  let(:project) { create(:project, name: "sai", tags: %w[ruby]) }

  def chips = all(".tag-pick-chip").map { it.text.strip }

  def field = find("[data-tag-field-input]")

  def results = all(".tag-pick-result").map(&:text)

  def save_project
    click_button "Save project"
    page.assert_selector("[data-toast]", text: "Project saved")
  end

  def saved_tags = projects.by_id(project.id).tags.map(&:name)

  before do
    create(:tag, name: "ruby", color: "mk-green")
    create(:tag, name: "rails", color: "mk-pink")
    create(:tag, :private, name: "rake")
    sign_in_to_admin
    visit "/admin/projects/#{project.id}/edit"
  end

  it "shows the tags as chips in place of the comma box", :aggregate_failures do
    expect(page).to have_no_field("project[tags]")
    expect(chips).to eq(["#ruby"])
  end

  it "lists the public tags that match, each in its color", :aggregate_failures do
    field.send_keys("ra")

    expect(results).to eq(["#rails", "New tag ra"])
    expect(page).to have_css(".tag-pick-result .tag.pink", text: "#rails")
  end

  it "picks a suggestion by keyboard alone and adds a chip in its color", :aggregate_failures do
    field.send_keys("rai", :down, :enter)

    expect(chips).to eq(["#ruby", "#rails"])
    expect(page).to have_css(".tag-pick-chip .tag.pink", text: "#rails")
  end

  it "closes the suggestions on Escape" do
    field.send_keys("ra")
    field.send_keys(:escape)

    expect(page).to have_no_css(".tag-pick-result")
  end

  it "saves a picked tag" do
    field.send_keys("rai", :down, :enter)
    save_project

    expect(saved_tags).to eq(%w[rails ruby])
  end

  it "takes a removed chip's tag off on save" do
    find("button[aria-label='Remove ruby']").click
    save_project

    expect(saved_tags).to eq([])
  end

  it "adds a chip for a new name and creates the tag on save", :aggregate_failures do
    field.send_keys("hanami", :enter)

    expect(chips).to eq(["#ruby", "#hanami"])
    save_project
    expect(saved_tags).to eq(%w[hanami ruby])
  end

  it "binds once after a morph" do
    execute_script(<<~JS)
      const main = document.querySelector("main");
      main.outerHTML = main.outerHTML;
      document.dispatchEvent(new Event("admin:morphed"));
      document.dispatchEvent(new Event("admin:morphed"));
    JS
    field.send_keys("r", :down)

    expect(page).to have_css(".tag-pick-result[aria-selected='true']", exact_text: "#rails")
  end

  it "suggests public tags in the post details" do
    visit "/admin/posts/#{create(:post, :draft).id}/edit"
    click_button "Details"
    find("dialog#post-details[open] [data-tag-field-input]").send_keys("r")

    expect(results).to eq(["#rails", "#ruby", "New tag r"])
  end
end
