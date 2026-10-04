# frozen_string_literal: true

RSpec.describe "Adding backups to the sync names", type: :migration do
  let(:gateway) { Record::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:sync_state_repo) { Record::Slice["repos.sync_state_repo"] }

  def enum_values = db.from(:pg_enum).join(:pg_type, oid: :enumtypid).where(typname: "sync_name").select_map(:enumlabel)

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def roll_back = migrate(20_261_003_000_137)

  describe "rolling back with a failed backup on hand" do
    before do
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::BACKUPS, :dump_failed)
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::PROJECTS, :github_failed)
      roll_back
    end

    it "takes backups back off the sync names" do
      expect(enum_values).not_to include("backups")
    end

    it "drops the backup failure and keeps the others" do
      expect(db[:sync_states].select_map(:sync)).to eq(["projects"])
    end
  end

  it "adds backups back on the way up" do
    roll_back
    migrate

    expect(enum_values).to include("backups")
  end

  it "rolls back again in the transaction that added it" do
    roll_back
    migrate
    roll_back

    expect(enum_values).not_to include("backups")
  end
end
