# frozen_string_literal: true

RSpec.describe "Task numbers", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:pod) { create(:project).id }
  let(:com) { create(:project).id }

  def number(id) = db[:tasks].where(id:).get(:number)

  def task(project_id = nil, **) = db[:tasks].insert(title: "task", list: "next", position: 1, project_id:, **)

  it "numbers tasks from 1 within each project and among tasks with no project" do
    ids = [task(pod), task(com), task, task(pod), task]

    expect(ids.map { number(it) }).to eq([1, 1, 1, 2, 2])
  end

  it "ignores a number given on insert" do
    task(pod)

    expect(number(task(pod, number: 1))).to eq(2)
  end

  it "gives a captured task the next number among tasks with no project" do
    task
    id = Tasks::Slice["operations.capture_task"].call({ title: "one", note: "", tags: "" }).value!.last.id

    expect(number(id)).to eq(2)
  end

  it "refuses two tasks with one number in a scope" do
    id = task

    expect { db[:tasks].where(id:).update(number: number(task)) }.to raise_error(Sequel::UniqueConstraintViolation)
  end

  it "gives a task moved to another project the next number there" do
    task(com)
    id = task(pod)
    db[:tasks].where(id:).update(project_id: com)

    expect(number(id)).to eq(2)
  end

  it "gives a task that loses its project the next number among tasks with no project" do
    task
    id = task(pod)
    db[:tasks].where(id:).update(project_id: nil)

    expect(number(id)).to eq(2)
  end

  it "keeps the number when an update leaves the project alone" do
    task(pod)
    id = task(pod)
    db[:tasks].where(id:).update(project_id: pod, title: "renamed")

    expect(number(id)).to eq(2)
  end

  it "never gives a deleted task's number to a new task in its project" do
    task(pod)
    db[:tasks].where(id: task(pod)).delete

    expect(number(task(pod))).to eq(3)
  end

  it "never gives a moved task's number to a new task in its old project" do
    task(pod)
    db[:tasks].where(id: task(pod)).update(project_id: com)

    expect(number(task(pod))).to eq(3)
  end

  it "never gives a deleted task's number to a new task with no project" do
    task
    db[:tasks].where(id: task).delete

    expect(number(task)).to eq(3)
  end

  it "never gives a moved task's number to a new task with no project" do
    task
    db[:tasks].where(id: task).update(project_id: pod)

    expect(number(task)).to eq(3)
  end

  describe "two tasks created at once", :commits do
    it "gives them different numbers" do
      other = Sequel.connect(db.opts.merge(max_connections: 1))
      other.get(Sequel.function(:pg_advisory_lock, Sequel.function(:hashtext, "tasks_next_number"), pod))
      threads = Array.new(2) { Thread.new { task(pod) } }.tap { Spec::DB::Locks.wait_for_waiters(db, 2) }
      other.disconnect

      expect(threads.map(&:value).map { number(it) }.sort).to eq([1, 2])
    end
  end
end
