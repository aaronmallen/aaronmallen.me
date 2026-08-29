# frozen_string_literal: true

module Projects
  module Operations
    class RefreshProjects < Blog::Operation
      include Deps[client: "record.github.client", project_repo: "repos.project_repo"]

      def call = step refresh

      private

      def refresh
        return Failure(:not_configured) unless client.configured?

        Success(project_repo.tracked.count { refreshed?(it) })
      rescue Record::GitHub::Client::RateLimited
        Failure(:rate_limited)
      rescue Record::GitHub::Client::Error => e
        Failure([:github_failed, e.message])
      end

      def refreshed?(project)
        stars = client.stars(project.repo)
        return false unless stars

        release = client.latest_release(project.repo)
        return false if project.stars == stars && project.release == release

        project_repo.update(project.id, stars:, release:)
        true
      end
    end
  end
end
