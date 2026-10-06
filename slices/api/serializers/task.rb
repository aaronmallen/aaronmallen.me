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

      SOURCE = Schema.object(
        {
          provider: { type: "string", enum: Blog::Types::TaskSourceProvider.values },
          url: Schema::STRING,
          reference: Schema.nullable({ type: "string", description: "the issue's short name, such as owner/repo#12" }),
          remote_state: { type: "string", enum: Blog::Types::TaskSourceState.values },
          seen_at: Schema.nullable(Schema::STAMP),
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
          position: Schema::INTEGER.merge(
            description: "the task's place in the order the owner set; lower comes first, ties go to the lower id",
          ),
          tags: Schema::TAGS,
          links: Schema.list(LINK),
          blocked: Schema::BOOLEAN,
          carried_count: Schema::INTEGER,
          worked_seconds: Schema::INTEGER,
          source: Schema.nullable(SOURCE).merge(description: "the issue the task syncs from, or null for a local task"),
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
          completed_at: Schema.nullable(Schema::STAMP),
        },
      ).freeze

      schema_attributes
      attribute :blocked, &:blocked?
      stamps :completed_at, :created_at, :updated_at
      tag_names

      def links(task)
        task.links.map { { label: it.label, id: it.task.id, title: it.task.title, status: it.task.status } }
      end

      def source(task)
        found = task.source
        return if found.nil?

        {
          provider: found.provider,
          url: found.url,
          reference: ::Tasks::SourceReference.for(found).name,
          remote_state: found.remote_state,
          seen_at: stamp(found.seen_at),
        }
      end

      def sprint_on(task) = day(params.fetch(:sprint_on) { task.sprint&.sprint_date })
    end
  end
end
