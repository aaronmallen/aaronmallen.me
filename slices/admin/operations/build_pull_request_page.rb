# frozen_string_literal: true

module Admin
  module Operations
    class BuildPullRequestPage
      KIND = Blog::Types::RecordKind["pull_request"]

      include Deps[
        list_record_links: "operations.list_record_links",
        pull_request_queries: "record.repos.pull_request_queries",
        settings: "settings",
      ]

      def call(id, records: Blog::Constants::EMPTY_HASH)
        pull_request = pull_request_queries.by_id(id)
        return unless pull_request

        {
          pull_request:,
          body_html: body_html(pull_request.body),
          records: list_record_links.call(KIND, pull_request.id, **records),
        }
      end

      private

      def body_html(body)
        return if body.strip.empty?

        ::Markdown::RemoteImages.to_links(::Markdown.to_html(body), origin: settings.site_origin)
      end
    end
  end
end
