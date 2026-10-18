# frozen_string_literal: true

RSpec.describe "Renumbering tasks with no project", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:migration) do
    path = Hanami.app.root.join("config/db/migrate/20261018200001_renumber_tasks_with_no_project.rb")
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last
  end

  let!(:tasks) { Array.new(3) { create(:task) } }
  let!(:link) { create(:task_link, from_task_id: tasks.first.id, to_task_id: tasks.last.id) }

  def number(task) = db[:tasks].where(id: task.id).get(:number)

  before do
    db[:tasks].where(id: tasks[1].id).update(project_id: create(:project).id)
    migration.apply(db, :up)
  end

  it "closes the gaps in their numbers in order" do
    expect([tasks.first, tasks.last].map { number(it) }).to eq([1, 2])
  end

  it "leaves the numbers in projects alone" do
    expect(number(tasks[1])).to eq(1)
  end

  it "gives the next task with no project the next number" do
    expect(create(:task).number).to eq(3)
  end

  it "shows the new number on links" do
    partner = Tasks::Slice["relations.task_links"].where(Sequel[:task_links][:id] => link.id).to_partners.one

    expect(partner[:partner_label]).to eq("2")
  end
end
