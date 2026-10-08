# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineSession < Serializer
      KINDS = [Blog::Types::TaskTimelineKind["session"]].freeze

      ID = "the session's ID, which update_work_session and delete_work_session take"

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: { type: "integer", description: ID },
          occurred_at: Helpers::Schema::STAMP,
          started_at: Helpers::Schema::STAMP,
          ended_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          seconds: { type: "integer", description: "how long the session ran, up to now while it runs" },
          running: Helpers::Schema::BOOLEAN,
        },
      ).freeze

      schema_attributes
      attribute :running, &:running?
      stamps :ended_at, :occurred_at, started_at: :occurred_at

      def id(entry) = entry.source_id
    end
  end
end
