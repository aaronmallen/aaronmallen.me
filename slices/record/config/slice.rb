# frozen_string_literal: true

module Record
  class Slice < Hanami::Slice
    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    export %w[
      operations.delete_journal_entry operations.queue_commit_import operations.record_sync_outcome
      operations.save_journal_entry operations.save_review_note operations.tag_journal_entry
      operations.untag_journal_entry operations.update_journal_entry repos.commit_queries repos.journal_entry_queries
      repos.pull_request_queries repos.review_note_queries repos.sync_state_queries
    ]
  end
end
