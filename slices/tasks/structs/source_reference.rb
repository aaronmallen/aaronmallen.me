# frozen_string_literal: true

module Tasks
  module Structs
    class SourceReference < Data.define(:provider, :path)
      ISSUE_PATH = "/issues/"
      ISSUE_SEPARATOR = "#"
      LINEAR = Blog::Types::TaskSourceProvider["linear"]
      LINEAR_ISSUE = %r{\A/([^/]+)/issue/([^/]+)}
      LINEAR_SEPARATOR = "/"

      def self.for(source) = new(provider: source.provider, path: URI(source.url).path)

      def key = linear? ? linear_parts&.last : name

      def name = linear? ? linear_parts&.join(LINEAR_SEPARATOR) : github_name

      private

      def github_name = path.delete_prefix("/").sub(ISSUE_PATH, ISSUE_SEPARATOR)

      def linear? = provider == LINEAR

      def linear_parts = path.match(LINEAR_ISSUE)&.captures
    end
  end
end
