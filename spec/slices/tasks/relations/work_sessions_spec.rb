# frozen_string_literal: true

RSpec.describe Tasks::Relations::WorkSessions do
  let(:task) { create(:task, :in_progress) }

  it "holds an open session" do
    expect(create(:work_session, task_id: task.id).ended_at).to be_nil
  end

  it "holds closed sessions beside an open one" do
    create(:work_session, :closed, task_id: task.id)
    create(:work_session, :closed, task_id: task.id)

    expect(create(:work_session, task_id: task.id).task_id).to eq(task.id)
  end

  it "refuses a second open session on one task" do
    create(:work_session, task_id: task.id)

    expect { create(:work_session, task_id: task.id) }
      .to raise_error(ROM::SQL::UniqueConstraintError, /work_sessions_one_open_index/)
  end

  it "keeps open sessions on different tasks apart" do
    create(:work_session, task_id: task.id)

    expect(create(:work_session, task_id: create(:task, :in_progress).id).ended_at).to be_nil
  end

  it "refuses a session that ends before it starts" do
    expect { create(:work_session, task_id: task.id, started_at: Time.now, ended_at: Time.now - 60) }
      .to raise_error(ROM::SQL::CheckConstraintError, /work_sessions_order_check/)
  end

  it "refuses a negative total on the task" do
    expect { Tasks::Slice["repos.task_repo"].update(task.id, worked_seconds: -1) }
      .to raise_error(ROM::SQL::CheckConstraintError, /tasks_worked_seconds_check/)
  end
end
