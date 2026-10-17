# frozen_string_literal: true

module API
  module Serializers
    class Task < Serializer
      LABELS = ::Tasks::Structs::Link::LABELS.values.flat_map(&:values).uniq.sort.freeze
      LABEL = { type: "string", description: "KEY-n for a task in a project, or n for a task with no project" }.freeze
      SLUG = { type: "string", pattern: "^[a-z0-9]+([.-][a-z0-9]+)*$", maxLength: 64 }.freeze

      CONTRIBUTOR = Helpers::Schema.object(
        { kind: { type: "string", enum: Blog::Types::ContributorKind.values } },
        optional: {
          agent: SLUG.merge(description: "the agent, such as claude-code; only with kind agent"),
          model: SLUG.merge(description: "the model's own id, such as claude-opus-5-5; only with kind agent"),
        },
      ).freeze

      LINK = Helpers::Schema.object(
        {
          label: { type: "string", enum: LABELS },
          id: Helpers::Schema::INTEGER,
          task_label: LABEL,
          title: Helpers::Schema::STRING,
          status: { type: "string", enum: Blog::Types::TaskStatus.values },
        },
      ).freeze

      SOURCE = Helpers::Schema.object(
        {
          provider: { type: "string", enum: Blog::Types::TaskSourceProvider.values },
          url: Helpers::Schema::STRING,
          reference: Helpers::Schema.nullable(
            { type: "string", description: "the issue's short name, such as owner/repo#12" },
          ),
          remote_state: { type: "string", enum: Blog::Types::TaskSourceState.values },
          seen_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
        },
      ).freeze

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          label: LABEL,
          title: Helpers::Schema::STRING,
          status: { type: "string", enum: Blog::Types::TaskStatus.values },
          list: Helpers::Schema.nullable({ type: "string", enum: Blog::Types::TaskList.values }),
          stage: { type: "string", enum: Blog::Types::TaskStage.values, description: "an open task's board column" },
          sprint_on: Helpers::Schema.nullable(Helpers::Schema::DAY),
          position: Helpers::Schema::INTEGER.merge(
            description: "the task's place in the order the owner set; lower comes first, ties go to the lower id",
          ),
          tags: Helpers::Schema::TAGS,
          contributors: Helpers::Schema.list(CONTRIBUTOR).merge(
            description: "who did the work; the owner when none is set",
          ),
          links: Helpers::Schema.list(LINK),
          blocked: Helpers::Schema::BOOLEAN,
          carried_count: Helpers::Schema::INTEGER,
          worked_seconds: Helpers::Schema::INTEGER,
          recur: Helpers::Schema.nullable(TaskSeries::SCHEMA).merge(
            description: "the series this task is the current copy of, or null when it does not recur",
          ),
          source: Helpers::Schema.nullable(SOURCE).merge(
            description: "the issue the task syncs from, or null for a local task",
          ),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
          completed_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
        },
      ).freeze

      schema_attributes
      attribute :blocked, &:blocked?
      def self.credits(contributors) = contributors.map { it.to_h.transform_keys(&:to_sym) }

      stamps :completed_at, :created_at, :updated_at
      tag_names

      def contributors(task) = task.credits

      def links(task)
        task.links.map do |link|
          linked = link.task
          {
            label: link.label, id: linked.id, task_label: linked.label,
            title: synced(linked.id, linked.title), status: linked.status,
          }
        end
      end

      def recur(task) = task.series && TaskSeries.new(task.series).serializable_hash

      def source(task)
        found = task.source
        return if found.nil?

        {
          provider: found.provider,
          url: found.url,
          reference: ::Tasks::Structs::SourceReference.for(found).name,
          remote_state: found.remote_state,
          seen_at: stamp(found.seen_at),
        }
      end

      def sprint_on(task) = day(params.fetch(:sprint_on) { task.sprint&.sprint_date })

      def title(task) = task.source ? untrusted(task.title) : task.title
    end
  end
end
