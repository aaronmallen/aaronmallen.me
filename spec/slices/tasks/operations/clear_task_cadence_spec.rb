# frozen_string_literal: true

RSpec.describe Tasks::Operations::ClearTaskCadence do
  let(:clear_cadence) { Tasks::Slice["operations.clear_task_cadence"] }
  let(:task) { create(:task) }

  def series = Tasks::Slice["relations.task_series"].to_a

  it "clears a task's cadence", :aggregate_failures do
    Tasks::Slice["operations.set_task_cadence"].call(task.id, { cadence: "month_end" })

    expect(clear_cadence.call(task.id)).to be_success
    expect(series).to be_empty
  end

  it "fails for a task with no cadence" do
    expect(clear_cadence.call(task.id).failure).to eq(:not_found)
  end
end
