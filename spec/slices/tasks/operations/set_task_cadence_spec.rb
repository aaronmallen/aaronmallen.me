# frozen_string_literal: true

RSpec.describe Tasks::Operations::SetTaskCadence, :frozen_clock do
  let(:set_cadence) { Tasks::Slice["operations.set_task_cadence"] }
  let(:task) { create(:task) }

  def pause(id) = Tasks::Slice["relations.task_series"].by_pk(id).update(paused: true)

  def series_ids = Tasks::Slice["relations.task_series"].pluck(:id)

  def sprint_on(task) = Tasks::Slice["relations.sprints"].by_pk(task.sprint_id).one[:sprint_date]

  def stored(row) = row.to_h.slice(*Tasks::Relations::TaskSeries::CADENCE).compact

  {
    "days" => { every: 3 },
    "weeks" => { every: 2, weekday: 4, starts_on: Date.new(2026, 10, 1) },
    "month_day" => { day: 31 },
    "month_end" => {},
    "month_weekday" => { week: -1, weekday: 5 },
    "yearly" => { month: 2, day: 29 },
  }.each do |cadence, fields|
    it "sets a #{cadence} cadence and keeps only its fields" do
      result = set_cadence.call(task.id, { cadence:, **fields, every: fields[:every] || 9, day: fields[:day] || 9 })

      expect(stored(result.value!)).to eq({ cadence:, **fields })
    end
  end

  it "takes form text" do
    result = set_cadence.call(task.id, { cadence: "weeks", every: "2", weekday: "4", starts_on: "2026-10-01" })

    expect(stored(result.value!)).to eq(cadence: "weeks", every: 2, weekday: 4, starts_on: Date.new(2026, 10, 1))
  end

  it "starts a weekly cadence today when no start date is given" do
    result = set_cadence.call(task.id, { cadence: "weeks", every: 1, weekday: 4, starts_on: "" })

    expect(result.value!.starts_on).to eq(Blog::TimeZone.today)
  end

  it "changes the cadence in place and keeps the series paused", :aggregate_failures do
    first = set_cadence.call(task.id, { cadence: "days", every: 3 }).value!.tap { pause(it.id) }

    changed = set_cadence.call(task.id, { cadence: "month_end" }).value!

    expect(series_ids).to eq([first.id])
    expect(stored(changed)).to eq(cadence: "month_end")
    expect(changed.paused).to be(true)
  end

  it "makes the next copy when the task is already done", :aggregate_failures do
    done = create(:task, :done, title: "Water the plants")

    series = set_cadence.call(done.id, { cadence: "days", every: 1 }).value!

    copy = Tasks::Slice["repos.task_queries"].by_id(series.task_id)
    expect(copy.id).not_to eq(done.id)
    expect([copy.title, copy.status, sprint_on(copy)]).to eq(["Water the plants", "open", Blog::TimeZone.today + 1])
  end

  context "with a copy its series has moved past" do
    let(:done) { create(:task, :done, title: "Water the plants") }
    let!(:series) { set_cadence.call(done.id, { cadence: "days", every: 1 }).value! }

    def open_ids = Tasks::Slice["relations.tasks"].where(status: "open").pluck(:id)

    it "refuses a cadence and leaves one series and one open copy", :aggregate_failures do
      result = set_cadence.call(done.id, { cadence: "days", every: 2 })

      expect(result.failure).to eq([:invalid, { cadence: ["moved"] }])
      expect([series_ids, open_ids]).to eq([[series.id], [series.task_id]])
    end

    it "refuses a cadence on a later copy the series has moved past" do
      copy = series.task_id
      Tasks::Slice["operations.complete_task"].call(copy)

      expect(set_cadence.call(copy, { cadence: "days", every: 2 }).failure).to eq([:invalid, { cadence: ["moved"] }])
    end

    it "takes a cadence once the series is cleared", :aggregate_failures do
      Tasks::Slice["operations.clear_task_cadence"].call(series.task_id)

      expect(set_cadence.call(done.id, { cadence: "days", every: 2 })).to be_success
      expect(series_ids.size).to eq(1)
    end
  end

  it "makes no copy for an open task", :aggregate_failures do
    series = set_cadence.call(task.id, { cadence: "days", every: 1 }).value!

    expect(series.task_id).to eq(task.id)
    expect(Tasks::Slice["relations.tasks"].pluck(:id)).to eq([task.id])
  end

  it "refuses an imported task", :aggregate_failures do
    imported = create(:task_source).task_id

    expect(set_cadence.call(imported, { cadence: "month_end" }).failure).to eq(:imported)
    expect(series_ids).to be_empty
  end

  it "fails for a missing task" do
    expect(set_cadence.call(0, { cadence: "month_end" }).failure).to eq(:not_found)
  end

  it "names each field a cadence is missing" do
    result = set_cadence.call(task.id, { cadence: "month_weekday" })

    expect(result.failure).to eq([:invalid, { week: ["blank"], weekday: ["blank"] }])
  end

  it "refuses an unknown cadence" do
    expect(set_cadence.call(task.id, { cadence: "hourly" }).failure).to match([:invalid, include(:cadence)])
  end

  it "refuses a day the month never has" do
    expect(set_cadence.call(task.id,
                            { cadence: "yearly", month: 2, day: 30 }).failure).to eq([:invalid, { day: ["format"] }])
  end

  it "refuses a week past the fourth" do
    result = set_cadence.call(task.id, { cadence: "month_weekday", week: 5, weekday: 1 })

    expect(result.failure).to eq([:invalid, { week: ["format"] }])
  end
end
