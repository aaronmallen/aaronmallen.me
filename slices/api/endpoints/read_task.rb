# frozen_string_literal: true

module API
  module Endpoints
    class ReadTask < TaskEndpoint
      SCHEMA = Helpers::Schema.by_id

      TIMELINE = "the task's comments, work sessions, moves, tag changes and status changes, oldest first"

      ENTRIES = [
        Serializers::TaskTimelineComment, Serializers::TaskTimelineSession, Serializers::TaskTimelineMove,
        Serializers::TaskTimelineTag, Serializers::TaskTimelineStatus,
      ].freeze

      SERIALIZERS = ENTRIES.flat_map { |serializer| serializer::KINDS.map { [it, serializer] } }.to_h.freeze

      REPLY = Helpers::Schema.widen(
        TaskEndpoint::REPLY,
        timeline: Helpers::Schema.list({ oneOf: ENTRIES.map(&:reference) }).merge(description: TIMELINE),
      ).freeze

      def handle(id:)
        task = task_queries.detailed(id)
        return not_found(Helpers::Wording.missing("task", id)) if task.nil?

        task_reply(task, timeline: task_queries.timeline(task.id).map { serialized(SERIALIZERS.fetch(it.kind), it) })
      end
    end
  end
end
