# frozen_string_literal: true

RSpec.describe API::Queries::Inbox do
  def count = API::Slice["queries.inbox_count"].call

  def listed = rows.map { [it.kind, it.record.id] }

  def mixed
    create(:message)
    create(:message, :read)
    create(:webmention)
    create(:webmention, :approved)
    synced
    synced(seen_at: Time.now)
    synced(:done)
  end

  def rows = API::Slice["queries.inbox"].call

  def synced(*traits, seen_at: nil, created_at: Time.now)
    create(:task, *traits, list: "external", created_at:).tap { create(:task_source, task: it, seen_at:) }
  end

  it "lists an unread message, a pending webmention and an unseen synced issue newest first" do
    task = synced(created_at: Time.now - 120)
    message = create(:message, received_at: Time.now - 60)
    webmention = create(:webmention, received_at: Time.now)

    expect(listed).to eq([[:webmention, webmention.id], [:message, message.id], [:task, task.id]])
  end

  it "gives each row its time" do
    message = create(:message, received_at: Time.now - 60)

    expect(rows.first.at).to be_within(1).of(message.received_at)
  end

  it "carries a synced issue's source and tags", :aggregate_failures do
    task = synced
    found = rows.first.record

    expect(found.source.task_id).to eq(task.id)
    expect(found.tags).to eq([])
  end

  it "leaves out a read or spam message, a moderated webmention and a seen synced issue" do
    create(:message, :read)
    create(:message, :spam)
    %i[approved spam ignored].each { create(:webmention, it) }
    synced(seen_at: Time.now)

    expect(rows).to be_empty
  end

  it "leaves out a task with no source" do
    create(:task)

    expect(rows).to be_empty
  end

  it "leaves out an unseen synced issue once it is done or canceled" do
    synced(:done)
    synced(:canceled)

    expect([rows, count]).to eq([[], 0])
  end

  it "counts the rows it lists" do
    mixed

    expect([count, rows.length]).to eq([3, 3])
  end

  it "counts nothing when nothing waits" do
    expect(count).to eq(0)
  end
end
