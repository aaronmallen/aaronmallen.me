# frozen_string_literal: true

RSpec.describe "API task recurrence", :frozen_clock, type: :request do
  def self.cadences
    {
      "days" => { "every" => 3 },
      "weeks" => { "every" => 2, "weekday" => 4, "starts_on" => "2026-10-01" },
      "month_day" => { "day" => 31 },
      "month_end" => {},
      "month_weekday" => { "week" => -1, "weekday" => 5 },
      "yearly" => { "month" => 2, "day" => 29 },
    }
  end

  def cadence(answer) = answer.fetch("recur")&.slice("cadence", *self.class.cadences.values.flat_map(&:keys))&.compact

  def recur(id, fields) = Tasks::Slice["operations.set_task_cadence"].call(id, fields).value!

  def series = Tasks::Slice["relations.task_series"]

  def tasks = Tasks::Slice["relations.tasks"]

  cadences.each do |kind, fields|
    it "captures a task on a #{kind} cadence" do
      answer = call_api(:post, "/tasks", { title: "Water the plants", recur: { cadence: kind, **fields } })

      expect([status, cadence(answer)]).to eq([201, { "cadence" => kind, **fields }])
    end

    it "changes a task to a #{kind} cadence" do
      task = create(:task)
      recur(task.id, { cadence: "days", every: 9 })

      expect(cadence(call_api(:patch, "/tasks/#{task.id}", { recur: { cadence: kind, **fields } })))
        .to eq({ "cadence" => kind, **fields })
    end
  end

  it "starts a weekly cadence today when no start is given" do
    answer = call_api(:post, "/tasks", { title: "Review", recur: { cadence: "weeks", every: 1, weekday: 4 } })

    expect(answer.dig("recur", "starts_on")).to eq(Blog::TimeZone.today.iso8601)
  end

  it "clears a cadence with null" do
    task = create(:task)
    recur(task.id, { cadence: "days", every: 3 })

    expect([call_api(:patch, "/tasks/#{task.id}", { recur: nil }).fetch("recur"), series.count]).to eq([nil, 0])
  end

  it "keeps a cadence a save leaves out" do
    task = create(:task)
    recur(task.id, { cadence: "days", every: 3 })

    expect(cadence(call_api(:patch, "/tasks/#{task.id}",
                            { title: "Renamed" }))).to eq("cadence" => "days", "every" => 3)
  end

  it "refuses a cadence that misses a field it needs and captures nothing" do
    answer = call_api(:post, "/tasks", { title: "Pay rent", recur: { cadence: "yearly", month: 2 } })

    expect([status, answer.fetch("errors"), tasks.count])
      .to eq([422, { "day" => ["month_day and yearly need a day"] }, 0])
  end

  it "refuses a day the month never reaches" do
    answer = call_api(:post, "/tasks", { title: "Pay rent", recur: { cadence: "yearly", month: 2, day: 30 } })

    expect(answer.fetch("errors")).to eq("day" => ["that month has fewer days"])
  end

  it "refuses a cadence on an imported task and saves nothing" do
    task = create(:task_source, task: create(:task, :external, title: "Fix the feed")).task
    answer = call_api(:patch, "/tasks/#{task.id}", { title: "Renamed", recur: { cadence: "month_end" } })

    expect([status, answer.fetch("errors"), series.count, tasks.by_pk(task.id).one[:title]])
      .to eq([422, { "recur" => ["an imported task cannot recur"] }, 0, "Fix the feed"])
  end

  it "refuses a cadence on a copy its series has moved past and keeps one series" do
    task = create(:task, :done)
    recur(task.id, { cadence: "days", every: 1 })
    answer = call_api(:patch, "/tasks/#{task.id}", { recur: { cadence: "days", every: 2 } })

    expect([status, answer.fetch("errors"), series.count, tasks.where(status: "open").count])
      .to eq([422, { "cadence" => ["its series has moved on to a newer copy; set the cadence there"] }, 1, 1])
  end

  it "shows a task's cadence when it reads and lists tasks" do
    task = create(:task)
    recur(task.id, { cadence: "month_weekday", week: 1, weekday: 1 })
    shown = { "cadence" => "month_weekday", "week" => 1, "weekday" => 1 }

    expect([cadence(call_api(:get, "/tasks/#{task.id}")), cadence(call_api(:get, "/tasks").fetch("tasks").first)])
      .to eq([shown, shown])
  end

  it "shows null for a task that does not recur" do
    expect(call_api(:get, "/tasks/#{create(:task).id}").fetch("recur")).to be_nil
  end

  describe "series" do
    let(:task) { create(:task, title: "Water the plants") }
    let(:row) { recur(task.id, { cadence: "days", every: 2 }) }

    def close(id) = Tasks::Slice["operations.complete_task"].call(id).value!

    it "lists each series once with its current copy" do
      row
      current = { "id" => task.id, "title" => "Water the plants", "status" => "open", "sprint_on" => nil }

      expect(call_api(:get, "/task_series").fetch("task_series"))
        .to match([include("id" => row.id, "cadence" => "days", "every" => 2, "paused" => false, "task" => current)])
    end

    it "pauses a series so closing its copy makes none" do
      answer = call_api(:post, "/task_series/#{row.id}/pause")
      close(task.id)

      expect([answer.fetch("paused"), tasks.count]).to eq([true, 1])
    end

    it "resumes a series whose copy closed by making the next copy at once" do
      call_api(:post, "/task_series/#{row.id}/pause")
      close(task.id)
      answer = call_api(:post, "/task_series/#{row.id}/resume")

      expect([answer.fetch("paused"), answer.dig("task", "status"), answer.dig("task", "sprint_on"), tasks.count])
        .to eq([false, "open", (Blog::TimeZone.today + 2).iso8601, 2])
    end

    it "resumes a series whose copy is open without making one" do
      call_api(:post, "/task_series/#{row.id}/pause")
      answer = call_api(:post, "/task_series/#{row.id}/resume")

      expect([answer.fetch("paused"), answer.dig("task", "id"), tasks.count]).to eq([false, task.id, 1])
    end

    %w[pause resume].each do |verb|
      it "answers 404 when asked to #{verb} a series that is not there" do
        call_api(:post, "/task_series/999/#{verb}")

        expect(status).to eq(404)
      end
    end
  end
end
