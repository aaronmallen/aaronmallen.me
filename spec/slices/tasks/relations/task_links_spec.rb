# frozen_string_literal: true

RSpec.describe Tasks::Relations::TaskLinks do
  let(:child) { create(:task) }
  let(:links) { Tasks::Slice["relations.task_links"] }

  def parent(of) = create(:task_link, :parent, from_task_id: create(:task).id, to_task_id: of.id)

  it "refuses a second parent on a task" do
    parent(child)

    expect { parent(child) }.to raise_error(ROM::SQL::UniqueConstraintError, /task_links_one_parent_key/)
  end

  it "gives one parent many children" do
    mother = create(:task)
    2.times { create(:task_link, :parent, from_task_id: mother.id, to_task_id: create(:task).id) }

    expect(links.where(from_task_id: mother.id).count).to eq(2)
  end

  it "takes a task blocked by two others" do
    2.times { create(:task_link, from_task_id: create(:task).id, to_task_id: child.id) }

    expect(links.where(to_task_id: child.id).count).to eq(2)
  end

  it "marks a new link as not synced" do
    expect(parent(child).synced).to be(false)
  end
end
