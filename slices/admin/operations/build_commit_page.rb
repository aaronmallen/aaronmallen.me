# frozen_string_literal: true

module Admin
  module Operations
    class BuildCommitPage
      KIND = Blog::Types::RecordKind["commit"]

      include Deps[commit_queries: "record.repos.commit_queries", list_record_links: "operations.list_record_links"]

      def call(id, records: Blog::Constants::EMPTY_HASH)
        commit = commit_queries.by_id(id)
        return unless commit

        { commit:, body_html: body_html(commit), records: list_record_links.call(KIND, commit.id, **records) }
      end

      private

      def body_html(commit)
        body = CommitMessage.body(commit.message)

        Blog::RemoteImages.to_links(::Posts::Markdown.to_html(body)) if body
      end
    end
  end
end
