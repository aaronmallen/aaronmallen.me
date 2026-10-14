# frozen_string_literal: true

module API
  module Endpoints
    class ReadTask < TaskEndpoint
      SCHEMA = Tasks::BY_ID

      TIMELINE = "comments, work sessions, moves, tag and status changes and when a series made the task, oldest first"

      ENTRIES = [
        Serializers::TaskTimelineComment, Serializers::TaskTimelineSession, Serializers::TaskTimelineMove,
        Serializers::TaskTimelineTag, Serializers::TaskTimelineStatus, Serializers::TaskTimelineRecur,
      ].freeze

      SERIALIZERS = ENTRIES.flat_map { |serializer| serializer::KINDS.map { [it, serializer] } }.to_h.freeze

      REPLY = Helpers::Schema.widen(
        TaskEndpoint::REPLY,
        timeline: Helpers::Schema.list({ oneOf: ENTRIES.map(&:reference) }).merge(description: TIMELINE),
      ).freeze

      def handle(id:)
        task = task_queries.detailed(id)
        return not_found(Helpers::Wording.missing("task", id)) if task.nil?

        owner = settings.owner_name
        timeline = task_queries.timeline(task.id).map { serialized(SERIALIZERS.fetch(it.kind), it, owner:) }

        task_reply(task, timeline:)
      end
    end
  end
end
