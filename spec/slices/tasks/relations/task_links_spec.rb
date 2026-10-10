# frozen_string_literal: true

RSpec.describe Tasks::Relations::TaskLinks do
  let(:child) { create(:task) }

  def parent(of) = create(:task_link, :parent, from_task_id: create(:task).id, to_task_id: of.id)

  it "refuses a second parent on a task" do
    parent(child)

    expect { parent(child) }.to raise_error(ROM::SQL::UniqueConstraintError, /task_links_one_parent_key/)
  end
end
