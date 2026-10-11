# frozen_string_literal: true

RSpec.describe "Admin tracked time", type: :feature do
  def figure = find(".task-meta [data-tracked-since]")

  def shift(element, minutes)
    execute_script(<<~JS, element, minutes)
      arguments[0].dataset.trackedSince = Number(arguments[0].dataset.trackedSince) - arguments[1] * 60000;
    JS
  end

  before do
    sprint = create(:sprint, sprint_date: Blog::TimeZone.today)
    task = create(:task, :in_progress, :in_sprint, sprint_id: sprint.id)
    create(:work_session, task_id: task.id, started_at: Time.now - 600)
    sign_in_to_admin
    visit "/admin/tasks"
  end

  it "adds a minute as each minute passes" do
    shift(figure, 1)

    expect(page).to have_css(".task-meta [data-tracked-since]", exact_text: "11m")
  end

  it "keeps counting on a figure the page draws again" do
    execute_script("arguments[0].outerHTML = arguments[0].outerHTML", figure)
    shift(figure, 63)

    expect(page).to have_css(".task-meta [data-tracked-since]", exact_text: "1h 13m")
  end
end
