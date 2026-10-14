# frozen_string_literal: true

RSpec.describe Tasks::Operations::CurrentSprint, :frozen_clock do
  subject(:operation) { described_class.new(sprint_mutations:) }

  let(:sprint_mutations) { Tasks::Slice["repos.sprint_mutations"] }
  let(:sprints) { Tasks::Slice["repos.sprint_queries"] }
  let(:today) { Blog::TimeZone.today }
  let(:yesterday) { create(:sprint, sprint_date: today - 1) }

  before do
    allow(sprint_mutations).to receive(:lock_roll_over).and_call_original
    allow(sprint_mutations).to receive(:claim).and_call_original
  end

  describe "when today's sprint exists and nothing waits behind it" do
    let!(:sprint) { create(:sprint, sprint_date: today) }

    it "returns it" do
      expect(operation.call.value!.id).to eq(sprint.id)
    end

    it "takes no lock and writes nothing", :aggregate_failures do
      operation.call

      expect(sprint_mutations).not_to have_received(:lock_roll_over)
      expect(sprint_mutations).not_to have_received(:claim)
    end

    it "leaves a finished task behind" do
      task = create(:task, :done, :in_sprint, sprint_id: yesterday.id)
      operation.call

      expect(Tasks::Slice["repos.task_queries"].by_id(task.id).sprint_id).to eq(yesterday.id)
    end
  end

  describe "when today's sprint does not exist" do
    it "creates it under the lock", :aggregate_failures do
      operation.call

      expect(sprints.on(today)).not_to be_nil
      expect(sprint_mutations).to have_received(:lock_roll_over)
    end

    it "carries an unfinished task into it" do
      task = create(:task, :in_sprint, sprint_id: yesterday.id)
      operation.call

      expect(Tasks::Slice["repos.task_queries"].by_id(task.id).sprint_id).to eq(sprints.on(today).id)
    end
  end

  describe "when today's sprint was claimed ahead and a task waits behind it" do
    let!(:sprint) { create(:sprint, sprint_date: today) }

    it "carries the task in under the lock", :aggregate_failures do
      task = create(:task, :in_sprint, sprint_id: yesterday.id)
      operation.call

      expect(Tasks::Slice["repos.task_queries"].by_id(task.id).sprint_id).to eq(sprint.id)
      expect(sprint_mutations).to have_received(:lock_roll_over)
    end
  end
end
