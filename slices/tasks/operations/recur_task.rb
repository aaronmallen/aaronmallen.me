# frozen_string_literal: true

module Tasks
  module Operations
    class RecurTask < Blog::Operation
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
        transaction do
          series = task_series_mutations.current(id)
          task = task_queries.by_id(id)

          make(series, task, at) if series && !series.paused && task.closed?
        end
      end

      private

      def carry(task, id, at)
        task_event_mutations.track(id, at) { task_mutations.replace_tags(id, task.tags.map(&:name)) }
        claim_photos.call(PHOTO_OWNER, id, task.note)
      end

      def clone(task, day, at)
        sprint_id = sprint_mutations.claim(day).id
        copy = task_mutations.append(title: task.title, note: task.note, project_id: task.project_id, sprint_id:)
        task_event_mutations.recur(copy.id, at)
        carry(task, copy.id, at)
        copy
      end

      def make(series, task, at)
        copy = clone(task, next_cadence_date.call(series.to_h, Blog::TimeZone.today(at)), at)
        task_series_mutations.advance(series.id, copy.id, at)
        task_queries.by_id(copy.id)
      end
    end
  end
end
