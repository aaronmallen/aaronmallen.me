# frozen_string_literal: true

module Record
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/record"), namespace: Record)

    config.shared_app_component_keys += %w[http]

    export %w[
      github.client linear.client operations.delete_journal_entry operations.queue_commit_import
      operations.record_country_sync_outcome operations.record_issue_sync_outcome
      operations.record_linear_issue_sync_outcome operations.record_projects_sync_outcome
      operations.record_rollup_sync_outcome operations.save_journal_entry operations.update_journal_entry
      queries.commit_by_id queries.commit_totals_today queries.commits_between queries.commits_last_synced_at
      queries.commits_today queries.journal_days queries.journal_entries_between queries.journal_entries_today
      queries.journal_entry_by_id queries.journal_entry_count queries.journal_streak queries.journal_word_count
      queries.recent_commit_repos queries.sync_failures
    ]
  end
end
