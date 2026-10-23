# frozen_string_literal: true

RSpec.shared_examples "a sync that steps aside while it runs" do
  describe "when another run is already going" do
    let(:elsewhere) { Sequel.connect(Record::Slice["db.rom"].gateways.fetch(:default).connection.opts) }

    before do
      elsewhere.get(Sequel.function(:pg_try_advisory_lock, Blog::DB::Relation.lock_key("#{sync} sync")))
      WebMock::RequestRegistry.instance.reset!
    end

    after { elsewhere.disconnect }

    it "leaves the run to the one holding the lock" do
      run

      expect(a_request(:any, %r{stub\.localhost/google/})).not_to have_been_made
    end

    it "reports nothing about a run it never made" do
      sync_state_mutations.record_failure(sync, :rate_limited)
      run

      expect(failure).to include(reason: "rate_limited", count: 1)
    end
  end
end
