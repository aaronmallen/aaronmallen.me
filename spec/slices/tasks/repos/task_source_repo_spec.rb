# frozen_string_literal: true

RSpec.describe Tasks::Repos::TaskSourceRepo do
  let(:connection) { Tasks::Slice["db.rom"].gateways.fetch(:default).connection }
  let(:elsewhere) { Sequel.connect(connection.opts) }
  let(:repo) { Tasks::Slice["repos.task_source_repo"] }

  after { elsewhere.disconnect }

  def hold(provider)
    elsewhere.get(Sequel.function(:pg_try_advisory_lock, described_class::SYNC_LOCKS.fetch(provider)))
  end

  describe "each provider's sync lock" do
    it "lets Linear sync while GitHub holds its lock" do
      hold("github")

      expect(repo.with_sync_lock("linear") { :ran }).to eq(:ran)
    end

    it "lets GitHub sync while Linear holds its lock" do
      hold("linear")

      expect(repo.with_sync_lock("github") { :ran }).to eq(:ran)
    end

    it "turns away a second sync of the same provider" do
      hold("linear")

      expect(repo.with_sync_lock("linear") { :ran }).to eq(Dry::Monads::Failure(:lock_busy))
    end
  end
end
