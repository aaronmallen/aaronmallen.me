# frozen_string_literal: true

RSpec.describe Tasks::Queries::UnseenTasks do
  def synced(*traits, seen_at: nil, created_at: Time.now)
    task = create(:task, *traits, list: "external", created_at:)
    create(:task_source, task:, seen_at:)
    task
  end

  def unseen = Tasks::Slice["queries.unseen_tasks"].call.map(&:id)

  it "lists unseen open synced tasks newest first" do
    older = synced(created_at: Time.now - 60)
    newer = synced

    expect(unseen).to eq([newer.id, older.id])
  end

  it "leaves out a synced task already seen" do
    synced(seen_at: Time.now)

    expect(unseen).to be_empty
  end

  it "leaves out a task with no source" do
    create(:task)

    expect(unseen).to be_empty
  end

  it "leaves out an unseen synced task that is done or canceled" do
    synced(:done)
    synced(:canceled)

    expect(unseen).to be_empty
  end

  it "carries each task's source and tags", :aggregate_failures do
    task = synced
    found = Tasks::Slice["queries.unseen_tasks"].call.first

    expect(found).to be_a(Tasks::Structs::Task)
    expect(found.source.task_id).to eq(task.id)
    expect(found.tags).to eq([])
  end
end
