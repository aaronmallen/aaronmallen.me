# frozen_string_literal: true

module Projects
  module Structs
    class Project < Blog::DB::Struct
      GITHUB = "https://github.com/%s"

      def self.repo_url(repo) = format(GITHUB, repo)

      def archived? = !archived_on.nil?

      def repo_url = (self.class.repo_url(repo) unless repo.to_s.strip.empty?)

      def slug = Blog::Types::Normalized::Slug.call(name) { nil }

      def status = archived? ? "archived" : "active"
    end
  end
end
