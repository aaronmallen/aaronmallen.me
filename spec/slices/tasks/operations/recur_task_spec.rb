# frozen_string_literal: true

RSpec.describe Tasks::Operations::RecurTask, :frozen_clock do
  let(:project) { create(:project) }
  let(:task) { create(:task, title: "Water the plants", note: "the ferns too", project_id: project.id) }
  let(:today) { Blog::TimeZone.today }

  def cadence(on = task, **fields) = slice("operations.set_task_cadence").call(on.id, fields).value!

  def complete(on = task) = slice("operations.complete_task").call(on.id)

  def copy_of(series) = slice("repos.task_queries").by_id(current(series).task_id)

  def current(series) = slice("repos.task_series_queries").by_id(series.id)

  def linked_kinds(id) = Links::Slice["relations.record_links"].where(left_kind: "task", left_id: id).pluck(:right_kind)

  def slice(key) = Tasks::Slice[key]

  def sprint_on(copy) = slice("relations.sprints").by_pk(copy.sprint_id).one[:sprint_date]

  def task_ids = slice("relations.tasks").pluck(:id)

  it "makes the next copy in the sprint for the next cadence date when a copy is completed", :aggregate_failures do
    series = cadence(cadence: "days", every: 3)

    complete

    copy = copy_of(series)
    expect(copy.id).not_to eq(task.id)
    expect([copy.title, copy.status, sprint_on(copy)]).to eq(["Water the plants", "open", today + 3])
  end

  it "makes the next copy when a copy is canceled" do
    series = cadence(cadence: "days", every: 1)

    slice("operations.cancel_task").call(task.id)

    expect(sprint_on(copy_of(series))).to eq(today + 1)
  end

  it "dates the next copy after today when a copy closes late" do
    late = create(:task, list: nil, sprint_id: create(:sprint, sprint_date: today - 20).id)
    series = cadence(late, cadence: "weeks", every: 1, weekday: today.wday, starts_on: (today - 28).iso8601)

    complete(late)

    expect(sprint_on(copy_of(series))).to eq(today + 7)
  end

  context "with a copy that has history" do
    let!(:series) { cadence(cadence: "month_end") }
    let(:copy) { copy_of(series) }

    before do
      slice("repos.task_mutations").replace_tags(task.id, %w[home money])
      Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "post", other_id: create(:post).id })
      create(:task_comment, task_id: task.id)
      create(:work_session, :closed, task_id: task.id)
      create(:task_contributor, task_id: task.id)
      create(:task_link, from_task_id: task.id, to_task_id: create(:task).id)
      complete
    end

    it "copies the title, note and tags" do
      expect([copy.title, copy.note, copy.tags.map(&:name)])
        .to eq(["Water the plants", "the ferns too", %w[home money]])
    end

    it "keeps the project and links the copy to nothing else", :aggregate_failures do
      expect(copy.project_id).to eq(project.id)
      expect(linked_kinds(copy.id)).to eq([])
    end

    it "starts the copy with no comments, time, contributors or task links" do
      expect([copy.comment_count, copy.worked_seconds, copy.contributors, copy.links]).to eq([0, 0, [], []])
    end
  end

  it "makes copies when tasks close in bulk" do
    other = create(:task)
    series = [cadence(cadence: "days", every: 1), cadence(other, cadence: "days", every: 2)]

    slice("operations.act_on_tasks").call({ act: "complete", ids: [task.id, other.id] })

    expect(series.map { sprint_on(copy_of(it)) }).to eq([today + 1, today + 2])
  end

  it "makes no copy when a paused series closes its copy", :aggregate_failures do
    series = cadence(cadence: "days", every: 1)
    slice("operations.pause_task_series").call(series.id)

    complete

    expect(current(series).task_id).to eq(task.id)
    expect(task_ids).to eq([task.id])
  end

  context "with a paused series" do
    let!(:series) { cadence(cadence: "days", every: 1).tap { slice("operations.pause_task_series").call(it.id) } }

    def resume = slice("operations.resume_task_series").call(series.id).value!

    it "makes the next copy at once when it resumes after its copy closed", :aggregate_failures do
      complete

      made = resume

      expect([made.id, sprint_on(made)]).to eq([current(series).task_id, today + 1])
    end

    it "makes nothing when it resumes while its copy is open" do
      resume

      expect(task_ids).to eq([task.id])
    end

    it "makes the next copy when the open copy closes after it resumes" do
      resume
      complete

      expect(copy_of(series).id).not_to eq(task.id)
    end
  end

  it "makes nothing when an earlier copy closes again" do
    series = cadence(cadence: "days", every: 1)
    complete
    slice("operations.reopen_task").call(task.id)

    complete

    expect(task_ids).to contain_exactly(task.id, current(series).task_id)
  end

  it "marks the copy on its timeline as made by its series" do
    series = cadence(cadence: "days", every: 1)

    complete

    expect(slice("repos.task_timeline_queries").for_task(current(series).task_id).map(&:kind).first).to eq("recurred")
  end

  it "fails to pause or resume a missing series" do
    expect(%w[pause resume].map { slice("operations.#{it}_task_series").call(0).failure }).to eq(%i[not_found] * 2)
  end
end
