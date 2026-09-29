# frozen_string_literal: true

RSpec.describe "Adding Linear to the task source and sync enums", type: :migration do
  let(:gateway) { Tasks::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:sync_state_repo) { Record::Slice["repos.sync_state_repo"] }

  def enum_values(type)
    db.from(:pg_enum).join(:pg_type, oid: :enumtypid).where(typname: type.to_s).select_map(:enumlabel)
  end

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def roll_back = migrate(20_260_928_000_043)

  describe "rolling back with a Linear source on hand" do
    let!(:linear) { create(:task_source, provider: "linear", url: "https://linear.app/acme/issue/ABC-1") }
    let!(:github) { create(:task_source) }

    before { roll_back }

    it "takes linear back off the providers" do
      expect(enum_values(:task_source_provider)).to eq(["github"])
    end

    it "drops the Linear source and keeps the GitHub one" do
      expect(db[:task_sources].select_map(:id)).to eq([github.id])
    end

    it "keeps the task the Linear source pointed at" do
      expect(db[:tasks].where(id: linear.task_id).count).to eq(1)
    end
  end

  it "takes started back off the states and reads a started source as open", :aggregate_failures do
    source = create(:task_source, remote_state: "started")
    roll_back

    expect(enum_values(:task_source_state)).not_to include("started")
    expect(db[:task_sources].where(id: source.id).get(:remote_state)).to eq("open")
  end

  describe "rolling back with a failed Linear sync on hand" do
    before do
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::LINEAR_ISSUES, :linear_failed)
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::ISSUES, :rate_limited)
      roll_back
    end

    it "takes linear_issues back off the sync names" do
      expect(enum_values(:sync_name)).not_to include("linear_issues")
    end

    it "drops the Linear failure and keeps GitHub's" do
      expect(db[:sync_states].select_map(:sync)).to eq(["issues"])
    end
  end

  it "adds all three back on the way up", :aggregate_failures do
    roll_back
    migrate

    expect(enum_values(:task_source_provider)).to include("linear")
    expect(enum_values(:task_source_state)).to include("started")
    expect(enum_values(:sync_name)).to include("linear_issues")
  end
end
