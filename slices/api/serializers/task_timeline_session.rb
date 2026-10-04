# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineSession < Serializer
      KINDS = [Blog::Types::TaskTimelineKind["session"]].freeze

      ID = "the session's ID, which update_work_session and delete_work_session take"

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: { type: "integer", description: ID },
          occurred_at: Schema::STAMP,
          started_at: Schema::STAMP,
          ended_at: Schema.nullable(Schema::STAMP),
          seconds: { type: "integer", description: "how long the session ran, up to now while it runs" },
          running: Schema::BOOLEAN,
        },
      ).freeze

      attributes :kind, :id, :occurred_at, :started_at, :ended_at, :seconds
      attribute :running, &:running?

      def ended_at(entry) = stamp(entry.ended_at)

      def id(entry) = entry.source_id

      def occurred_at(entry) = stamp(entry.occurred_at)

      def started_at(entry) = stamp(entry.occurred_at)
    end
  end
end
