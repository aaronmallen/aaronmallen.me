# frozen_string_literal: true

module Admin
  module Operations
    class BuildPullRequestPage
      include Deps[pull_request_queries: "record.repos.pull_request_queries"]

      def call(id)
        pull_request = pull_request_queries.by_id(id)
        return unless pull_request

        { pull_request:, body_html: body_html(pull_request.body) }
      end

      private

      def body_html(body)
        ::Tasks::RemoteImages.to_links(::Posts::Markdown.to_html(body)) unless body.strip.empty?
      end
    end
  end
end
