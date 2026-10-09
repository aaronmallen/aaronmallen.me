# frozen_string_literal: true

module Contact
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/contact"), namespace: Contact)

    export %w[
      operations.act_on_messages operations.create_message operations.delete_message operations.mark_message
      operations.snooze_messages operations.wake_message repos.message_queries
    ]
  end
end
