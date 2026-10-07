# frozen_string_literal: true

RSpec.describe "Admin inbox", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:task) { create(:task, :external, title: "Fix the feed") }

  def modal = find("dialog#task-create[open]")

  def save(**fields)
    within(".li", text: "Fix the feed") { click_link("Edit") }
    modal.assert_selector("[data-task-edit]")
    expect(page).to have_current_path("/admin/inbox")
    fields.each { |name, value| modal.fill_in("task[#{name}]", with: value) }
    modal.click_button("Save")
  end

  before do
    create(:task_source, task:)
    sign_in_to_admin
    visit "/admin/inbox"
  end

  it "saves a tag change in the dialog, stays on the inbox and drops the issue", :aggregate_failures do
    save(tags: "feeds")

    expect(page).to have_css("[data-toast]", text: "Task saved")
    expect(page).to have_current_path("/admin/inbox")
    expect(page).to have_no_css(".li", text: "Fix the feed")
    expect(repo.by_id(task.id).tags.map(&:name)).to eq(["feeds"])
  end

  it "keeps the issue when the dialog saves only a note", :aggregate_failures do
    save(note: "Look at the cache")

    expect(page).to have_current_path("/admin/inbox")
    expect(page).to have_css(".li", text: "Fix the feed")
  end
end
