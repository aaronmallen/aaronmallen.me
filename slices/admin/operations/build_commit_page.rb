# frozen_string_literal: true

module Admin
  module Operations
    class BuildCommitPage
      KIND = Blog::Types::RecordKind["commit"]

      include Deps[commit_by_id: "record.queries.commit_by_id", list_record_links: "operations.list_record_links"]

      def call(id, records: Blog::Constants::EMPTY_HASH)
        commit = commit_by_id.call(id)
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
