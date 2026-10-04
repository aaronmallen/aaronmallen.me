# frozen_string_literal: true

RSpec.describe Tasks::Operations::DeleteTaskTagRule do
  include Dry::Monads[:result]

  def delete(id) = Tasks::Slice["operations.delete_task_tag_rule"].call(id)

  def tag_names(task) = Tasks::Slice["repos.task_repo"].by_id(task.id).tags.map(&:name)

  let(:site) { create(:task, :external).tap { create(:task_source, task: it) } }
  let(:rule) { Tasks::Slice["operations.save_task_tag_rule"].call({ pattern: "aaronmallen/*", tags: "ruby" }).value! }

  it "deletes the rule" do
    delete(rule.id)

    expect(Tasks::Slice["relations.task_tag_rules"].count).to eq(0)
  end

  it "leaves every task's tags as they were" do
    site
    delete(rule.id)

    expect(tag_names(site)).to eq(%w[ruby])
  end

  it "answers not found for a missing rule" do
    expect(delete(0)).to eq(Failure(:not_found))
  end
end
