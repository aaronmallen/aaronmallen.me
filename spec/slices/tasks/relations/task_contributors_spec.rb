# frozen_string_literal: true

RSpec.describe Tasks::Relations::TaskContributors do
  let(:db) { Tasks::Slice["db.rom"].gateways[:default].connection }
  let(:task) { create(:task) }

  def record(**columns) = create(:task_contributor, task_id: task.id, **columns)

  it "refuses an owner with an agent" do
    expect { record(kind: "owner", model: nil) }
      .to raise_error(ROM::SQL::CheckConstraintError, /task_contributors_kind_check/)
  end

  it "refuses an agent with no model" do
    expect { record(model: nil) }.to raise_error(ROM::SQL::CheckConstraintError, /task_contributors_kind_check/)
  end

  it "refuses an agent with no agent name" do
    expect { record(agent: nil) }.to raise_error(ROM::SQL::CheckConstraintError, /task_contributors_kind_check/)
  end

  it "refuses an agent that is not a lowercase slug" do
    expect { record(agent: "Claude Code") }.to raise_error(ROM::SQL::CheckConstraintError, /contributor_slug_check/)
  end

  it "refuses a model longer than 64 characters" do
    expect { record(model: "a" * 65) }.to raise_error(ROM::SQL::CheckConstraintError, /contributor_slug_check/)
  end

  it "refuses a kind it does not know" do
    expect { db[:task_contributors].insert(task_id: task.id, kind: "human") }
      .to raise_error(Sequel::DatabaseError, /contributor_kind/)
  end

  it "refuses a second owner row on the same task" do
    record(kind: "owner", agent: nil, model: nil)

    expect { record(kind: "owner", agent: nil, model: nil) }
      .to raise_error(ROM::SQL::UniqueConstraintError, /task_contributors_task_id_agent_model_index/)
  end

  it "refuses the same agent and model twice on a task" do
    record

    expect { record }.to raise_error(ROM::SQL::UniqueConstraintError, /task_contributors_task_id_agent_model_index/)
  end
end
