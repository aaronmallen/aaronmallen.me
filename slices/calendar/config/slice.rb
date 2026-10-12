# frozen_string_literal: true

module Calendar
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/calendar"), namespace: Calendar)

    import keys: %w[operations.record_sync_outcome], from: :record

    import keys: %w[google.client], from: :google

    export %w[
      operations.create_event operations.delete_event operations.edit_event operations.show_calendars
      repos.calendar_queries
    ]
  end
end
