# frozen_string_literal: true

RSpec.describe "Admin task cadence", :frozen_clock, type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_queries"] }

  def cadence(task, **fields) = Tasks::Slice["operations.set_task_cadence"].call(task.id, fields).value!

  def capture(**recur)
    post "/admin/tasks", { _csrf_token: admin_csrf_token, task: { title: "Water the plants", list: "next", recur: } }
  end

  def captured = open_in_list("next").find { it.title == "Water the plants" }

  def enabled(within) = page.all("#{within} [name^='task[recur]']:not([disabled])").map { it["name"][/\[(\w+)\]\z/, 1] }

  def save(task, **fields)
    form = { title: task.title, list: "next", note: "", tags: "", **fields }

    post "/admin/tasks/#{task.id}", { _csrf_token: admin_csrf_token, filter: "next", task: form }
  end

  def series_repo = Tasks::Slice["repos.task_series_queries"]

  def stored(task)
    series_repo.by_task(task.id)&.then { it.to_h.slice(*Tasks::Relations::TaskSeries::CADENCE).compact }
  end

  before { sign_in_to_admin }

  describe "creating a task" do
    {
      "every few days" => [{ cadence: "days", every: "3" }, { cadence: "days", every: 3 }],
      "every few weeks" => [
        { cadence: "weeks", every: "2", weekday: "4", starts_on: "2026-01-01" },
        { cadence: "weeks", every: 2, weekday: 4, starts_on: Date.new(2026, 1, 1) },
      ],
      "a day each month" => [{ cadence: "month_day", day: "31" }, { cadence: "month_day", day: 31 }],
      "the last day of each month" => [{ cadence: "month_end" }, { cadence: "month_end" }],
      "a weekday each month" => [
        { cadence: "month_weekday", week: "-1", weekday: "5" }, { cadence: "month_weekday", week: -1, weekday: 5 },
      ],
      "a date each year" => [{ cadence: "yearly", month: "2", day: "29" }, { cadence: "yearly", month: 2, day: 29 }],
    }.each do |kind, (posted, saved)|
      it "sets #{kind}" do
        capture(**posted)

        expect(stored(captured)).to eq(saved)
      end
    end

    it "starts every few weeks today when the form gives no first day" do
      capture(cadence: "weeks", every: "1", weekday: "1", starts_on: "")

      expect(stored(captured)[:starts_on]).to eq(today)
    end

    it "sets no cadence when it never repeats" do
      capture(cadence: "", every: "3")

      expect(stored(captured)).to be_nil
    end

    describe "with a cadence it refuses" do
      before { capture(cadence: "days", every: "0") }

      it "keeps the task out", :aggregate_failures do
        expect(last_response.status).to eq(422)
        expect(captured).to be_nil
      end

      it "says what went wrong beside the field" do
        expect(page).to have_css("#new-every-error", text: i18n.t("ui.components.tasks.field_error.every.format"))
      end

      it "keeps the kind it was given and shows its fields", :aggregate_failures do
        expect(page).to have_css("#new-cadence option[selected][value='days']")
        expect(enabled("main")).to eq(%w[cadence every])
      end
    end
  end

  describe "the new task page" do
    before { get "/admin/tasks/new" }

    it "offers each cadence kind after never" do
      expect(page.all("#new-cadence option").map(&:value)).to eq(["", *Blog::Types::TaskCadence.values])
    end

    it "bounds the number fields and lists the weeks as the cadence contract does", :aggregate_failures do
      expect(%w[every day].map { page.find("#new-#{it}", visible: :all).then { |field| [field[:min], field[:max]] } })
        .to eq([%w[1 365], %w[1 31]])
      expect(page.all("#new-week option", visible: :all).map(&:value)).to eq(%w[1 2 3 4 -1])
    end

    it "hides and disables every field a kind needs until one is picked", :aggregate_failures do
      expect(page.all("main [data-cadence-for]:not([hidden])", visible: :all)).to be_empty
      expect(enabled("main")).to eq(%w[cadence])
    end
  end

  describe "the create dialog" do
    it "holds the cadence picker" do
      get "/admin/tasks"

      expect(page).to have_css("#task-create form select[name='task[recur][cadence]']", visible: :all)
    end
  end

  describe "editing a task" do
    let(:task) { create(:task, title: "Water the plants") }

    def form_id = "task-#{task.id}-form"

    def next_copy(**fields)
      series = cadence(task, **fields)
      Tasks::Slice["operations.complete_task"].call(task.id)
      repo.by_id(series_repo.by_id(series.id).task_id)
    end

    def starts_on_hint = i18n.t("ui.components.tasks.cadence_fields.starts_on_hint")

    it "shows its cadence with only that kind's fields enabled", :aggregate_failures do
      cadence(task, cadence: "month_weekday", week: -1, weekday: 5)
      get "/admin/tasks/#{task.id}/edit", filter: "next"

      expect(page).to have_css("##{form_id} [name='task[recur][cadence]'] option[selected][value='month_weekday']")
      expect(enabled("##{form_id}")).to eq(%w[cadence week weekday])
      expect(page.find("##{form_id} select[name='task[recur][week]'] option[selected]").value).to eq("-1")
    end

    it "says weeks count from the first day it is given", :aggregate_failures do
      copy = next_copy(cadence: "weeks", every: 2, weekday: (today - 7).wday, starts_on: today - 7)
      get "/admin/tasks/#{copy.id}/edit", filter: "upcoming"

      expect(Tasks::Slice["repos.sprint_queries"].on(today + 7).id).to eq(copy.sprint_id)
      expect(page.all("#task-#{copy.id}-form .hint").map(&:text)).to include(starts_on_hint)
    end

    it "changes its cadence" do
      cadence(task, cadence: "days", every: 3)
      save(task, recur: { cadence: "yearly", month: "7", day: "4" })

      expect(stored(task)).to eq(cadence: "yearly", month: 7, day: 4)
    end

    it "sets one on a task that had none" do
      save(task, recur: { cadence: "month_end" })

      expect(stored(task)).to eq(cadence: "month_end")
    end

    it "clears it" do
      cadence(task, cadence: "days", every: 3)
      save(task, recur: { cadence: "" })

      expect(stored(task)).to be_nil
    end

    it "keeps it when the form sends no picker" do
      cadence(task, cadence: "days", every: 3)
      save(task)

      expect(stored(task)).to eq(cadence: "days", every: 3)
    end

    it "keeps the title as it was when the cadence is refused", :aggregate_failures do
      save(task, title: "Water the ferns", recur: { cadence: "month_day", day: "" })

      expect(last_response.status).to eq(422)
      expect(repo.by_id(task.id).title).to eq("Water the plants")
    end
  end

  describe "an imported task" do
    let(:task) { create(:task_source, task: create(:task, :external, title: "Fix the feed")).task }

    it "shows no cadence picker" do
      get "/admin/tasks/#{task.id}/edit", filter: "external"

      expect(page).to have_no_css("#task-#{task.id}-form [name^='task[recur]']", visible: :all)
    end

    it "refuses a cadence", :aggregate_failures do
      save(task, list: "external", recur: { cadence: "days", every: "3" })

      expect(last_response.status).to eq(422)
      expect(stored(task)).to be_nil
    end
  end
end
