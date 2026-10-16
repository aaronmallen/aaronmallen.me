# frozen_string_literal: true

module Calendar
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/calendar"), namespace: Calendar)

    config.shared_app_component_keys += %w[honeybadger.agent]

    import keys: %w[repos.post_queries], from: :posts

    import keys: %w[operations.record_sync_outcome repos.journal_entry_queries], from: :record

    import keys: %w[repos.social_post_queries], from: :social

    import keys: %w[repos.sprint_queries], from: :tasks

    export %w[
      operations.create_event operations.delete_event operations.edit_event operations.move_event
      operations.show_calendars
      repos.calendar_day_queries repos.calendar_queries
    ]
  end
end
