# frozen_string_literal: true

module Admin
  module Operations
    class BuildProjectsPage
      FIELDS = %i[blurb from_year org role to_year].freeze

      include Deps[
        all_work_entries: "projects.queries.work_entries",
        archived_projects: "projects.queries.archived",
        live_projects: "projects.queries.live",
      ]

      def call(filter: Blog::Types::ProjectFilter["live"], params: nil, errors: Dry::Core::Constants::EMPTY_HASH)
        live = live_projects.call
        archived = archived_projects.call

        {
          filter:,
          projects: filter == Blog::Types::ProjectFilter["archived"] ? archived : live,
          work_entries: work_entries(filter),
          work_errors: errors,
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
        return Dry::Core::Constants::EMPTY_ARRAY unless filter == Blog::Types::ProjectFilter["work"]

        all_work_entries.call
      end
    end
  end
end
