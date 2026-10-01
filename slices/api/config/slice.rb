# frozen_string_literal: true

module API
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/api"), namespace: API)

    config.no_auto_register_paths += %w[serializers]

    config.actions.csrf_protection = false

    import keys: %w[
      operations.delete_journal_entry operations.save_journal_entry operations.update_journal_entry
      queries.journal_entries_between queries.journal_entry_by_id
    ], from: :record

    export %w[
      endpoints.create_journal_entry endpoints.delete_journal_entry endpoints.list_journal_entries
      endpoints.read_journal_entry endpoints.update_journal_entry operations.mint_token operations.revoke_token
      queries.live_tokens
    ]
  end
end
