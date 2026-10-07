# frozen_string_literal: true

module Admin
  module Operations
    class BuildProjectsPage
      FIELDS = %i[blurb from_year org role to_year].freeze
      KIND = Blog::Types::RecordKind["work_entry"]
      WORK = Blog::Types::ProjectFilter["work"]

      include Deps[
        list_record_links: "operations.list_record_links",
        project_queries: "projects.repos.project_queries",
        work_entry_queries: "projects.repos.work_entry_queries",
      ]

      def call(
        filter: Blog::Types::ProjectFilter["live"], params: nil, errors: Blog::Constants::EMPTY_HASH, linking: nil,
        records: Blog::Constants::EMPTY_HASH
      )
        live = project_queries.live
        archived = project_queries.archived
        entries = work_entries(filter)

        {
          filter:,
          projects: filter == Blog::Types::ProjectFilter["archived"] ? archived : live,
          work_entries: entries,
          work_errors: errors,
          work_links: work_links(entries, linking, records),
          work_values: values(params),
          **counts(live, archived),
        }
      end

      private

      def counts(live, archived)
        {
          archived_count: archived.size,
          live_count: live.size,
          stars: (live + archived).sum(&:stars),
        }
      end

      def values(params)
        fields = Blog::Types::Fields[params]

        FIELDS.to_h { [it, Blog::Types::Text[fields[it]]] }
      end

      def work_entries(filter)
        return Blog::Constants::EMPTY_ARRAY unless filter == WORK

        work_entry_queries.all
      end

      def work_links(entries, id, records)
        entry = entries.find { it.id == id } if id
        return unless entry

        { entry:, records: list_record_links.call(KIND, entry.id, **records) }
      end
    end
  end
end
