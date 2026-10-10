# frozen_string_literal: true

RSpec.describe Tasks::Relations::TaskEvents do
  let(:task) { create(:task) }
  let(:today) { Blog::TimeZone.today }
  let(:relation) { Tasks::Slice["db.rom"].relations[:task_events] }

  def record(kind, **columns) = create(:task_event, task_id: task.id, kind:, tag_name: nil, **columns)

  def rolled_back(tag_name)
    record("tagged", tag_name:)
    raise Sequel::Rollback
  end

  it "rolls back its own writes and keeps the ones around it" do
    relation.dataset.db.transaction do
      record("tagged", tag_name: "kept")
      relation.track([task.id], Time.now, diff: ->(*) { [] }) { rolled_back("dropped") }
    end

    expect(relation.for_task(task.id).pluck(:tag_name)).to eq(["kept"])
  end

  it "refuses a move with no destination" do
    expect { record("moved", from_list: "next") }
      .to raise_error(ROM::SQL::CheckConstraintError, /task_events_kind_check/)
  end

  it "refuses a move with no origin" do
    expect { record("moved", to_list: "next") }
      .to raise_error(ROM::SQL::CheckConstraintError, /task_events_kind_check/)
  end

  it "refuses a move from both a list and a sprint" do
    expect { record("moved", from_list: "next", from_sprint_on: today, to_list: "someday") }
      .to raise_error(ROM::SQL::CheckConstraintError, /task_events_kind_check/)
  end

  it "refuses a move that goes nowhere" do
    expect { record("moved", from_list: "next", to_list: "next") }
      .to raise_error(ROM::SQL::CheckConstraintError, /task_events_kind_check/)
  end

  it "refuses a status change missing the status it came from" do
    expect { record("status_changed", to_status: "done") }
      .to raise_error(ROM::SQL::CheckConstraintError, /task_events_kind_check/)
  end

  it "refuses a status change to the same status" do
    expect { record("status_changed", from_status: "open", to_status: "open") }
      .to raise_error(ROM::SQL::CheckConstraintError, /task_events_kind_check/)
  end

  it "refuses a tag change with no tag" do
    expect { record("tagged") }.to raise_error(ROM::SQL::CheckConstraintError, /task_events_kind_check/)
  end

  it "refuses columns another kind needs" do
    expect { record("tagged", tag_name: "money", to_list: "next") }
      .to raise_error(ROM::SQL::CheckConstraintError, /task_events_kind_check/)
  end
end
