# frozen_string_literal: true

module Admin
  module Operations
    class SearchPalette
      PER_KIND = 5
      PAGE = Blog::Page.new(number: 1, size: Blog::Types::SearchKind.values.size * PER_KIND)
      WORK = Blog::Types::ProjectFilter["work"]

      include Deps["i18n", "routes", search: "search.queries.search"]

      def call(text)
        search.call(text:, page: PAGE, per_kind: PER_KIND).rows.group_by(&:kind).map do |kind, hits|
          { kind:, hits: hits.map { entry(it) } }
        end
      end

      private

      def entry(hit)
        {
          id: hit.source_id, title: hit.title, match: hit.match, date: i18n.l(hit.day, format: :medium),
          href: href(hit),
        }
      end

      def href(hit)
        id = hit.source_id

        case hit.kind
        when "task" then routes.path(:admin_task, id:)
        when "post" then routes.path(:admin_edit_post, id:)
        when "commit" then routes.path(:admin_commit, id:)
        when "project" then routes.path(:admin_edit_project, id:)
        when "person" then routes.path(:admin_edit_person, id:)
        else listed_href(hit)
        end
      end

      def journal_href(day) = "#{routes.path(:admin_journal, to: day)}##{UI::Components::Journal::Day.anchor(day)}"

      def listed_href(hit)
        case hit.kind
        when "social" then routes.path(:admin_social, edit: hit.source_id)
        when "journal" then journal_href(hit.day)
        when "work" then routes.path(:admin_projects, filter: WORK)
        when "message" then routes.path(:admin_messages, status: hit.status)
        when "webmention" then routes.path(:admin_webmentions, status: hit.status)
        end
      end
    end
  end
end
