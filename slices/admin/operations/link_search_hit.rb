# frozen_string_literal: true

module Admin
  module Operations
    class LinkSearchHit
      PAGES = {
        Blog::Types::SearchKind["message"] => :admin_messages,
        Blog::Types::SearchKind["webmention"] => :admin_webmentions,
      }.freeze
      PERSON = Blog::Types::SearchKind["person"]

      include Deps["routes"]

      def call(hit)
        kind = hit.kind
        id = hit.source_id
        row = Blog::Helpers::RecordKinds.searched(kind)
        return Blog::Helpers::RecordKinds.path(routes, row.kind, id:, day: hit.day) if row
        return routes.path(:admin_edit_person, id:) if kind == PERSON

        routes.path(PAGES.fetch(kind), status: hit.status)
      end
    end
  end
end
