# frozen_string_literal: true

module API
  module Serializers
    class Task < Serializer
      LABELS = %w[blocks blocked_by duplicates duplicated_by relates].freeze

      LINK = Schema.object(
        {
          label: { type: "string", enum: LABELS },
          id: Schema::INTEGER,
          title: Schema::STRING,
          status: { type: "string", enum: Blog::Types::TaskStatus.values },
        },
      ).freeze

      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          title: Schema::STRING,
          note: Schema::STRING,
          status: { type: "string", enum: Blog::Types::TaskStatus.values },
          list: Schema.nullable({ type: "string", enum: Blog::Types::TaskList.values }),
          sprint_on: Schema.nullable(Schema::DAY),
          tags: Schema::TAGS,
          links: Schema.list(LINK),
          blocked: Schema::BOOLEAN,
          carried_count: Schema::INTEGER,
          worked_seconds: Schema::INTEGER,
          created_at: Schema::STAMP,
          completed_at: Schema.nullable(Schema::STAMP),
        },
      ).freeze

      attributes :id, :title, :note, :status, :list, :sprint_on, :tags, :links
      attribute :blocked, &:blocked?
      attributes :carried_count, :worked_seconds, :created_at, :completed_at

      def completed_at(task) = stamp(task.completed_at)

      def created_at(task) = stamp(task.created_at)

      def links(task)
        task.links.map { { label: it.label, id: it.task.id, title: it.task.title, status: it.task.status } }
      end

      def sprint_on(task) = day(params.fetch(:sprint_on) { task.sprint&.sprint_date })

      def tags(task) = task.tags.map(&:name)
    end
  end
end
