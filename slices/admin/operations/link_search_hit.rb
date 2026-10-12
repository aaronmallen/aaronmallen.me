# frozen_string_literal: true

module Admin
  module Operations
    class LinkSearchHit
      ALL = Blog::Types::MailFolder["all"]
      MESSAGE = Blog::Types::SearchKind["message"]
      PERSON = Blog::Types::SearchKind["person"]
      SPAM = Blog::Types::MailFolder["spam"]

      include Deps["routes"]

      def call(hit)
        kind = hit.kind
        id = hit.source_id
        row = Blog::Helpers::RecordKinds.searched(kind)
        return Blog::Helpers::RecordKinds.path(routes, row.kind, id:, day: hit.day) if row
        return routes.path(:admin_edit_person, id:) if kind == PERSON
        return thread_path(id, hit.status) if kind == MESSAGE

        routes.path(:admin_webmentions, status: hit.status)
      end

      private

      def thread_path(id, status)
        Helpers::MailList.back(routes, { folder: status == SPAM ? SPAM : ALL }, thread: id)
      end
    end
  end
end
