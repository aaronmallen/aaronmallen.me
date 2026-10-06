# frozen_string_literal: true

module API
  module Endpoints
    class ReadTask < TaskEndpoint
      SCHEMA = Schema.by_id

      TIMELINE = "the task's comments, work sessions, moves, tag changes and status changes, oldest first"

      ENTRIES = [
        Serializers::TaskTimelineComment, Serializers::TaskTimelineSession, Serializers::TaskTimelineMove,
        Serializers::TaskTimelineTag, Serializers::TaskTimelineStatus,
      ].freeze

      SERIALIZERS = ENTRIES.flat_map { |serializer| serializer::KINDS.map { [it, serializer] } }.to_h.freeze

      REPLY = Schema.widen(
        TaskEndpoint::REPLY,
        timeline: Schema.list({ oneOf: ENTRIES.map(&:reference) }).merge(description: TIMELINE),
      ).freeze

      include Deps[task_timeline: "tasks.queries.task_timeline"]

      def handle(id:)
        task = task_by_id.call(id)
        return not_found(Wording.missing("task", id)) if task.nil?

        task_reply(task, timeline: task_timeline.call(task.id).map { serialized(SERIALIZERS.fetch(it.kind), it) })
      end
    end
  end
end
