# frozen_string_literal: true

module Record
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/record"), namespace: Record)

    config.shared_app_component_keys += %w[http]

    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[repos.connection_queries], from: :services

    export %w[
      github.client linear.client operations.delete_journal_entry operations.queue_commit_import
      operations.record_sync_outcome operations.save_journal_entry operations.save_review_note
      operations.update_journal_entry
      repos.commit_queries repos.journal_entry_queries repos.pull_request_queries repos.review_note_queries
      repos.sync_state_queries
    ]
  end
end
