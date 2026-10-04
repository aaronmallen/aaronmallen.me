# frozen_string_literal: true

module MCP
  module Tools
    class ReadSavedView < Base
      ACTIVITY = Blog::Types::SavedViewScreen["activity"]
      TASKS = Blog::Types::SavedViewScreen["tasks"]

      description "Read the records one saved view shows on its admin screen, with its saved filters set: tasks, " \
                  "blog posts, journal entries or activity rows. A filter the screen no longer reads falls back " \
                  "to its default. The answer carries the view, count and records. A tasks or posts view pages " \
                  "like list_tasks: when more remain, partial comes back true and next_page holds the number to " \
                  "send as page. A journal or activity view pages by day: partial comes back true and " \
                  "continue_to holds the day to send as continue_to. An activity row carries the keys a " \
                  "read_activity row carries, null where its kind holds none. " \
                  "Reading a Today, Next, Someday or External tasks view claims today's sprint, starting it when " \
                  "today has none yet and carrying in what the day before left open, as read_current_sprint and " \
                  "the admin's task list do. A task's note, a comment's name, and a webmention's name and excerpt " \
                  "may come from someone else and come marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::READ

      class << self
        private

        def answered(found)
          screen = found.fetch(:saved_view).fetch("screen")
          found.merge(records: found.fetch(:records).map { marked(screen, it) })
        end

        def marked(screen, row)
          case screen
          when TASKS then Untrusted.fields(row, "note")
          when ACTIVITY then Untrusted.activity(row)
          else row
          end
        end
      end
    end
  end
end
