# frozen_string_literal: true

module API
  module Serializers
    class TagOverview < Serializer
      PROJECT = Blog::Types::TagScope["project"]
      SCOPES = Blog::Types::GlobalTagScope.values

      DESCRIPTION = Helpers::Schema.nullable(Helpers::Schema::STRING)
      DESCRIPTIONS = Helpers::Schema.object(
        Blog::Constants::EMPTY_HASH, optional: Blog::Types::TagScope.values.to_h { [it.to_sym, DESCRIPTION] },
      ).merge(
        description: "each scope's markdown description of the tag, or null; a project tag has only project",
      ).freeze

      ROWS = {
        posts: Post.reference,
        projects: Helpers::Schema.object(
          {
            id: Helpers::Schema::INTEGER,
            key: Helpers::Schema::STRING,
            name: Helpers::Schema::STRING,
            status: { type: "string", enum: %w[active archived] },
          },
        ),
        tasks: Helpers::Schema.object(
          {
            id: Helpers::Schema::INTEGER,
            title: Helpers::Schema::STRING,
            status: { type: "string", enum: Blog::Types::TaskStatus.values },
            completed_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          },
        ),
        journal_entries: Helpers::Schema.object(
          {
            id: Helpers::Schema::INTEGER,
            date: Helpers::Schema::DAY,
            opening: { type: "string", description: "the entry's first characters; read_journal_entry has it all" },
          },
        ),
        decisions: Helpers::Schema.object(
          {
            id: Helpers::Schema::INTEGER,
            title: Helpers::Schema::STRING,
            status: { type: "string", enum: Blog::Types::DecisionStatus.values },
          },
        ),
        notes: Helpers::Schema.object(
          { id: Helpers::Schema::INTEGER, title: Helpers::Schema::STRING, updated_at: Helpers::Schema::STAMP },
        ),
        messages: Helpers::Schema.object(
          {
            id: Helpers::Schema::INTEGER,
            subject: Helpers::Schema::STRING,
            received_at: Helpers::Schema::STAMP,
          },
        ),
      }.freeze

      COUNTS = Helpers::Schema.object({}, optional: ROWS.transform_values { Helpers::Schema::INTEGER })
                              .merge(description: "how many records of each kind carry the tag")
                              .freeze

      SCHEMA = Helpers::Schema.object(
        { name: Helpers::Schema::STRING, descriptions: DESCRIPTIONS, counts: COUNTS },
        optional: ROWS.transform_values { Helpers::Schema.paged({ records: Helpers::Schema.list(it) }) },
      ).freeze

      attributes :name, :descriptions, :counts
      ROWS.each_key { |kind| attributes kind, if: proc { it.pages.key?(kind) } }

      def decisions(overview) = paged(overview, :decisions) { { id: it.id, title: it.title, status: it.status } }

      def descriptions(overview)
        project_tag = overview.tag(PROJECT)
        return { PROJECT => project_tag.description } if project_tag

        SCOPES.to_h { [it, overview.tag(it)&.description] }
      end

      def journal_entries(overview)
        paged(overview, :journal_entries) { { id: it.id, date: day(it.entry_date), opening: it.body } }
      end

      def messages(overview)
        paged(overview, :messages) do |thread|
          { id: thread.id, subject: untrusted(thread.subject), received_at: stamp(thread.received_at) }
        end
      end

      def notes(overview)
        paged(overview, :notes) { { id: it.id, title: it.title, updated_at: stamp(it.updated_at) } }
      end

      def posts(overview) = paged(overview, :posts) { Post.new(it).serializable_hash }

      def projects(overview)
        paged(overview, :projects) { { id: it.id, key: it.key, name: it.name, status: it.status } }
      end

      def tasks(overview)
        paged(overview, :tasks) do |task|
          { id: task.id, title: synced(task.id, task.title), status: task.status,
            completed_at: stamp(task.completed_at) }
        end
      end

      private

      def paged(overview, kind, &)
        found = overview.pages.fetch(kind)

        { records: found.rows.map(&), **Helpers::Paging.fields(found) }
      end
    end
  end
end
