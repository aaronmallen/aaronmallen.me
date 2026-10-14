# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineRecur < Serializer
      KINDS = [Blog::Types::TaskTimelineKind["recurred"]].freeze

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          occurred_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :occurred_at
    end
  end
end
