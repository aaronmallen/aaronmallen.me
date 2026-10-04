# frozen_string_literal: true

module Admin
  module Operations
    class BuildProjectsPage
      FIELDS = %i[blurb from_year org role to_year].freeze
      KIND = Blog::Types::RecordKind["work_entry"]
      WORK = Blog::Types::ProjectFilter["work"]

      include Deps[
        all_work_entries: "projects.queries.work_entries",
        archived_projects: "projects.queries.archived",
        list_record_links: "operations.list_record_links",
        live_projects: "projects.queries.live",
      ]

      def call(
        filter: Blog::Types::ProjectFilter["live"], params: nil, errors: Blog::Constants::EMPTY_HASH, linking: nil,
        records: Blog::Constants::EMPTY_HASH
      )
        live = live_projects.call
        archived = archived_projects.call
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
          featured_count: live.count(&:featured),
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

        all_work_entries.call
      end

      def work_links(entries, id, records)
        entry = entries.find { it.id == id } if id
        return unless entry

        { entry:, records: list_record_links.call(KIND, entry.id, **records) }
      end
    end
  end
end
