# frozen_string_literal: true

module Tasks
  module Operations
    class RecurTask
      PHOTO_OWNER = Blog::Types::PhotoOwner["task"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        next_cadence_date: "operations.next_cadence_date",
        sprint_mutations: "repos.sprint_mutations",
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
        task_series_mutations: "repos.task_series_mutations",
      ]

      def call(id, at: Time.now)
        task_series_mutations.transaction do
          series = task_series_mutations.current(id)
          make(series, id, at) if series && !series.paused
        end
      end

      private

      def carry(task, id, at)
        task_event_mutations.track(id, at) { task_mutations.replace_tags(id, task.tags.map(&:name)) }
        claim_photos.call(PHOTO_OWNER, id, task.note)
      end

      def clone(task, series, day, at)
        sprint_id = sprint_mutations.claim(day).id
        copy = task_mutations.append(
          title: task.title, note: task.note, project_id: task.project_id, sprint_id:, series_id: series.id,
        )
        task_event_mutations.recur(copy.id, at)
        carry(task, copy.id, at)
        copy
      end

      def make(series, id, at)
        task = task_queries.detailed(id)
        return unless task.closed?

        day = next_cadence_date.call(series.to_h, task.recurs_after(Blog::TimeZone.today(at)))
        copy = clone(task, series, day, at)
        task_series_mutations.advance(series.id, copy.id, at)
        task_queries.by_id(copy.id)
      end
    end
  end
end
