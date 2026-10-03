# frozen_string_literal: true

RSpec.describe "Adding seen_at to task sources", type: :migration do
  let(:gateway) { Tasks::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def roll_back = migrate(20_261_003_000_082)

  def source(task)
    db[:task_sources].insert(task_id: task.id, provider: "github", remote_id: "I_1", url: "https://x.test/1")
  end

  it "reads every source that exists before it as seen" do
    task = create(:task)
    roll_back
    id = source(task)
    migrate

    expect(db[:task_sources].where(id:).get(:seen_at)).not_to be_nil
  end

  it "leaves a source made after it unseen" do
    id = source(create(:task))

    expect(db[:task_sources].where(id:).get(:seen_at)).to be_nil
  end

  it "drops the column on the way down" do
    roll_back

    expect(db[:task_sources].columns).not_to include(:seen_at)
  end
end
