# frozen_string_literal: true

module Contact
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/contact"), namespace: Contact)

    export %w[
      operations.act_on_messages operations.create_message operations.mark_message
      queries.by_id queries.by_status queries.count_with_status queries.counts_received_between queries.received_between
      queries.unread_messages
    ]
  end
end
