# frozen_string_literal: true

RSpec.describe Record::Operations::RecordIssueSyncOutcome do
  include Dry::Monads[:result]

  let(:record) { Record::Slice["operations.record_issue_sync_outcome"] }
  let(:sync_state_repo) { Record::Slice["repos.sync_state_repo"] }

  def failure = sync_state_repo.failure(Record::Repos::SyncStateRepo::ISSUES)

  it "records a failed issue sync in sync_states" do
    record.call(Failure([:rate_limited, "GitHub rate limited GraphQL"]))

    expect(failure).to include(count: 1, message: "GitHub rate limited GraphQL", reason: "rate_limited")
  end

  it "clears the failure when the next sync succeeds" do
    record.call(Failure(:not_configured))
    record.call(Success(nil))

    expect(failure).to be_nil
  end
end
