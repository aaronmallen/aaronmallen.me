# frozen_string_literal: true

RSpec.describe Backups::Jobs::BackUpDatabase do
  let(:dumps) { (1..9).map { format("database-202609%02dT053000Z.dump", it) } }
  let(:sync_state_repo) { Record::Slice["repos.sync_state_repo"] }

  def back_up = described_class.new.perform

  def back_up_failing
    back_up
  rescue described_class::BackupFailed
    nil
  end

  def failure = sync_state_repo.failure(Record::Repos::SyncStateRepo::BACKUPS)

  def upload = a_request(:put, %r{\A#{backup_store_url}/database-\d{8}T\d{6}Z\.dump\z})

  def with_dumper(**database)
    settings = Hanami.app["settings"].database
    replace_component("dumper", Backups::Dumper.new(database: settings.merge(database)))
  end

  before do
    connect_backup_store
    stub_request(:put, %r{\A#{backup_store_url}/})
    stub_request(:delete, %r{\A#{backup_store_url}/})
    stub_backup_listing(*dumps)
  end

  describe "a good run" do
    it "uploads a pg_dump of the database in the custom format" do
      back_up

      expect(upload.with { it.body.start_with?("PGDMP") }).to have_been_made
    end

    it "keeps the 7 newest dumps and deletes the rest", :aggregate_failures do
      back_up

      dumps.first(2).each { expect(a_request(:delete, backup_store_url(it))).to have_been_made }
      dumps.last(7).each { expect(a_request(:delete, backup_store_url(it))).not_to have_been_made }
    end

    it "deletes nothing while the bucket holds 7 or fewer" do
      stub_backup_listing(*dumps.last(7))
      back_up

      expect(a_request(:delete, /.*/)).not_to have_been_made
    end

    it "signs its requests with the backup key" do
      back_up

      expect(upload.with { it.headers["Authorization"].include?("Credential=backup-access-key/") }).to have_been_made
    end

    it "waits 300 seconds for the store to answer" do
      expect(Backups::Slice["backup_store.client"].instance_variable_get(:@connection).config.http_read_timeout)
        .to eq(300)
    end

    it "clears a failure an earlier run left" do
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::BACKUPS, :upload_failed)
      back_up

      expect(failure).to be_nil
    end
  end

  describe "a dump that fails" do
    before { with_dumper(name: "no_such_database_for_backups") }

    it "raises so Honeybadger hears of it" do
      expect { back_up }.to raise_error(described_class::BackupFailed, /dump_failed/)
    end

    it "records the failure for Today" do
      back_up_failing

      expect(failure).to include(reason: "dump_failed", message: /no_such_database_for_backups/)
    end

    it "uploads nothing and leaves the dumps in the bucket alone", :aggregate_failures do
      back_up_failing

      expect(upload).not_to have_been_made
      expect(a_request(:delete, /.*/)).not_to have_been_made
    end
  end

  describe "an upload that fails" do
    before { stub_request(:put, %r{\A#{backup_store_url}/}).to_return(status: 500) }

    it "raises so Honeybadger hears of it" do
      expect { back_up }.to raise_error(described_class::BackupFailed, /upload_failed/)
    end

    it "records the failure for Today" do
      back_up_failing

      expect(failure).to include(reason: "upload_failed")
    end

    it "leaves the dumps in the bucket alone" do
      back_up_failing

      expect(a_request(:delete, /.*/)).not_to have_been_made
    end
  end

  describe "a prune that fails" do
    before { stub_request(:delete, %r{\A#{backup_store_url}/}).to_timeout }

    it "records the failure for Today and raises", :aggregate_failures do
      expect { back_up }.to raise_error(described_class::BackupFailed, /prune_backups_failed/)
      expect(failure).to include(reason: "prune_backups_failed")
    end
  end

  describe "with no backup settings" do
    before do
      connect_backup_store(access_key: nil, secret_key: nil)
      allow(Sidekiq.logger).to receive(:warn)
    end

    it "reaches no store and runs no dump", :aggregate_failures do
      back_up

      expect(a_request(:any, /.*/)).not_to have_been_made
      expect(failure).to be_nil
    end

    it "reports it is not configured" do
      back_up

      expect(Sidekiq.logger).to have_received(:warn).with(described_class::NOT_CONFIGURED)
    end
  end

  describe "with only photo store settings" do
    before do
      connect_media_store
      connect_backup_store(access_key: nil, bucket: nil, endpoint: nil, secret_key: nil)
      allow(Sidekiq.logger).to receive(:warn)
    end

    it "reaches no store and runs no dump", :aggregate_failures do
      back_up

      expect(a_request(:any, /.*/)).not_to have_been_made
      expect(failure).to be_nil
    end
  end
end
