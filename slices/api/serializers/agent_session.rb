# frozen_string_literal: true

module API
  module Serializers
    class AgentSession < Serializer
      MARKED = "; marked untrusted, since the agent wrote it"
      TEXT = { type: "string" }.freeze

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: TEXT.merge(description: "what the session is for#{MARKED}"),
          agent: TEXT.merge(description: "the agent that opened it"),
          model: TEXT.merge(description: "the model the agent ran on"),
          client: Helpers::Schema.nullable(TEXT.merge(description: "the client the agent ran in#{MARKED}")),
          project_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER).merge(
            description: "the project it ran in; null when it named none, or its project was deleted",
          ),
          repo: Helpers::Schema.nullable(Helpers::Schema::REPO),
          branch: Helpers::Schema.nullable(TEXT.merge(description: "the branch it worked on#{MARKED}")),
          task_ids: Helpers::Schema.list(Helpers::Schema::INTEGER).merge(description: "the tasks it worked on"),
          tags: Helpers::Schema::TAGS.merge(description: "its tags; a session in a project has its project's own tags"),
          loaded: Helpers::Schema.list(
            Helpers::Schema.object({ memory_file_id: Helpers::Schema::INTEGER, path: Helpers::Schema::STRING }),
          ).merge(description: "the memory files start_session loaded, by path"),
          memory_changes: Helpers::Schema.list(
            Helpers::Schema.object(
              {
                event_id: Helpers::Schema::INTEGER,
                memory_file_id: Helpers::Schema::INTEGER,
                op: { type: "string", enum: Blog::Types::MemoryEventOp.values },
                fact_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
              },
            ),
          ).merge(description: "the history entries it wrote, oldest first; read_memory_file gives their text"),
          artifact_versions: Helpers::Schema.list(
            Helpers::Schema.object({ artifact_id: Helpers::Schema::INTEGER, number: Helpers::Schema::INTEGER }),
          ).merge(description: "the artifact versions it wrote, oldest first"),
          started_at: Helpers::Schema::STAMP,
          last_seen_at: Helpers::Schema::STAMP.merge(description: "when a call last named it"),
          ended_at: Helpers::Schema.nullable(Helpers::Schema::STAMP).merge(
            description: "when it closed; null while it runs",
          ),
        },
      ).freeze

      schema_attributes
      stamps :started_at, :last_seen_at, :ended_at

      def artifact_versions(session)
        session.artifact_versions.map { { artifact_id: it.artifact_id, number: it.number } }
      end

      def branch(session) = session.branch&.then { untrusted(it) }

      def client(session) = session.client&.then { untrusted(it) }

      def loaded(session) = session.agent_session_loads.map { { memory_file_id: it.memory_file_id, path: it.path } }

      def memory_changes(session)
        session.memory_events.map do |event|
          { event_id: event.id, memory_file_id: event.memory_file_id, op: event.op, fact_id: event.memory_fact_id }
        end
      end

      def tags(session) = session.tags.map(&:name)

      def task_ids(session) = session.agent_session_tasks.map(&:task_id)

      def title(session) = untrusted(session.title)
    end
  end
end
