# frozen_string_literal: true

RSpec.describe "Admin project board", type: :feature do
  let(:project) { create(:project, name: "blog") }
  let(:task) { create(:task, title: "Write the brief") }

  def card = find(".kc", text: "Write the brief")

  def item(label) = find("[data-context-menu] .ctx-item", text: label)

  def keep_page = execute_script("window.kept = true")

  def kept_page? = evaluate_script("window.kept === true")

  before do
    sign_in_to_admin
    Links::Slice["repos.record_link_mutations"].link(["task", task.id], ["project", project.id])
    visit "/admin/projects/#{project.id}"
    keep_page
  end

  it "moves a card by its arrow in place", :aggregate_failures do
    card.hover
    card.find("button[aria-label='Move to ready']").click

    expect(page).to have_css(".kcol.k-ready .kc", text: "Write the brief")
    expect(page).to have_css(".toast", text: "Moved ##{task.id} to ready")
    expect(kept_page?).to be(true)
  end

  it "moves a card from its menu in place", :aggregate_failures do
    card.right_click
    item("Board column").hover
    item("in progress").click

    expect(page).to have_css(".kcol.k-in_progress .kc", text: "Write the brief")
    expect(kept_page?).to be(true)
  end

  it "opens the task drawer from a card" do
    card.find(".kc-title").click

    expect(page).to have_css("dialog[data-task-panel][open]", text: "Write the brief")
  end
end
