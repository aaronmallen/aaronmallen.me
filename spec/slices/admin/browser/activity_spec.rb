# frozen_string_literal: true

RSpec.describe "Admin activity", type: :feature do
  let(:task) { create(:task, :in_progress, title: "clear the gutters") }
  let!(:comments) do
    Array.new(12) do |n|
      create(:task_comment, task_id: task.id, body: "note #{n}\n\n#{'Long line. ' * 40}", created_at: at(today, 8, n))
    end
  end

  def open_row(text)
    find(".activity-event", text:).click
    find("dialog#task-panel[open]").assert_selector("h1", exact_text: "clear the gutters")
    settle("#task-panel")
  end

  def shown?(selector)
    evaluate_script(<<~JS, selector)
      (() => {
        const body = document.querySelector("[data-task-panel-body]").getBoundingClientRect();
        const item = document.querySelector(arguments[0]).getBoundingClientRect();
        return item.top >= body.top && item.top < body.bottom;
      })()
    JS
  end

  before do
    sign_in_to_admin
    visit "/admin/activity"
  end

  it "opens a comment's task in the panel over Activity", :aggregate_failures do
    open_row("note 11")

    expect(page).to have_current_path("/admin/activity")
    expect(shown?("#task-comment-#{comments.last.id}")).to be(true)
  end
end
