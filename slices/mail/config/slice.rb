# frozen_string_literal: true

module Mail
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/mail"), namespace: Mail)

    import keys: %w[operations.record_sync_outcome], from: :record

    import keys: %w[google.client], from: :google

    export %w[
      operations.act_on_messages operations.create_message operations.delete_message operations.label_message
      operations.mark_message operations.snooze_messages operations.wake_message repos.message_queries
      repos.thread_queries
    ]
  end
end
