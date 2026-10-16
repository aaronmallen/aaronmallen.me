# frozen_string_literal: true

RSpec.describe "Admin task cadence picker in the task panel", type: :feature do
  let!(:task) { create(:task, title: "Water the plants") }

  def panel = find("dialog#task-panel[open]")

  def shown = panel.all("[data-cadence-for]:not([hidden]) :is(input, select):not([disabled])").map { it["name"] }

  def stored = Tasks::Slice["repos.task_series_queries"].by_task(task.id)

  before do
    sign_in_to_admin
    visit "/admin/tasks?filter=next"
    find(".task-title", exact_text: "Water the plants").click
    panel.click_link("Edit")
    panel.select("Every few weeks", from: "Repeats")
  end

  it "shows the fields every few weeks needs" do
    expect(shown).to eq(%w[task[recur][every] task[recur][weekday] task[recur][starts_on]])
  end

  it "saves the cadence", :aggregate_failures do
    panel.fill_in("task[recur][every]", with: "2")
    panel.click_button("Save")
    panel.assert_selector("[data-task-read] h1", exact_text: "Water the plants")

    expect(stored.cadence).to eq("weeks")
    expect(stored.every).to eq(2)
  end
end
