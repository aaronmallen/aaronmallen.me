# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineStatus < Serializer
      KINDS = [Blog::Types::TaskTimelineKind["status_changed"]].freeze

      STATUS = { type: "string", enum: Blog::Types::TaskStatus.values }.freeze

      SCHEMA = Schema.object(
        { kind: { type: "string", enum: KINDS }, occurred_at: Schema::STAMP, from_status: STATUS, to_status: STATUS },
      ).freeze

      attributes :kind, :occurred_at, :from_status, :to_status

      def occurred_at(entry) = stamp(entry.occurred_at)
    end
  end
end
