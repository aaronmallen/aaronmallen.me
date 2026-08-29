# frozen_string_literal: true

module Admin
  module Actions
    module Commits
      class Show < Action
        include Deps[commit_by_id: "record.queries.commit_by_id"]

        def handle(request, response)
          commit = commit_by_id.call(record_id(request))
          not_found(response) unless commit

          response.render(view, commit:, body_html: body_html(commit))
        end

        private

        def body_html(commit)
          body = CommitMessage.body(commit.message)

          ::Posts::Markdown.to_html(body) if body
        end
      end
    end
  end
end
