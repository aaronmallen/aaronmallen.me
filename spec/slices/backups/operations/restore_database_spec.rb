# frozen_string_literal: true

require "tmpdir"

RSpec.describe Backups::Operations::RestoreDatabase, :commits do
  let(:dir) { Dir.mktmpdir }
  let(:dump) { Backups::Dumper.new(database: settings).call(File.join(dir, "database-20261015T003000Z.dump")) }
  let(:settings) { Hanami.app["settings"].database }

  after { FileUtils.remove_entry(dir) }

  def databases = Posts::Slice["db.rom"].gateways[:default].connection[:pg_database].select_map(:datname)

  def restore(source = dump) = described_class.new.call(source)

  def scratch_databases = databases.select { it.start_with?("#{settings[:name]}_restore_") }

  context "with rows in the key tables" do
    before do
      create(:post)
      create(:task)
    end

    it "restores the dump and counts the rows in each key table" do
      expect(restore.value!).to include("posts" => 1, "tasks" => 1, "schema_migrations" => be_positive)
    end

    it "drops the scratch database and leaves the one the settings name", :aggregate_failures do
      restore

      expect(scratch_databases).to be_empty
      expect(databases).to include(settings[:name])
    end

    it "fetches a dump by name from the backups bucket" do
      connect_backup_store
      stub_request(:head, backup_store_url("database-20261015T003000Z.dump"))
      stub_request(:get, backup_store_url("database-20261015T003000Z.dump")).to_return(body: File.binread(dump))

      expect(restore("database-20261015T003000Z.dump").value!).to include("posts" => 1)
    end
  end

  it "fails and drops the scratch database when a key table comes back empty", :aggregate_failures do
    create(:post)
    result = restore

    expect(result.failure).to match([:restore_failed, "tasks came back empty"])
    expect(scratch_databases).to be_empty
  end

  it "fails when the file is not a dump" do
    path = File.join(dir, "not-a-dump")
    File.write(path, "nothing")

    expect(restore(path).failure).to match([:restore_failed, /not a valid archive|input file/])
  end

  it "fails when the bucket holds no dump by that name" do
    connect_backup_store
    stub_request(:head, backup_store_url("database-missing.dump")).to_return(status: 404)

    expect(restore("database-missing.dump").failure).to eq([:not_found, "database-missing.dump"])
  end

  it "fails when neither a file nor a backups bucket holds the dump" do
    expect(restore("database-missing.dump").failure).to eq([:not_found, "database-missing.dump"])
  end
end
