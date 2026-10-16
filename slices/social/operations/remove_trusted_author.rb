# frozen_string_literal: true

module Social
  module Operations
    class RemoveTrustedAuthor < Blog::Operation
      include Deps[
        normalize_author_url: "operations.normalize_author_url",
        webmention_mutations: "repos.webmention_mutations",
      ]

      def call(author_url)
        author_url = normalize_author_url.call(author_url)

        step found(webmention_mutations.distrust(author_url).positive? && author_url)
      end
    end
  end
end
