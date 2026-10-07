# frozen_string_literal: true

module Record
  module Jobs
    class BackfillRepoCommits < Blog::Job
      SOONEST_RETRY = 60

      include Deps["github.client", backfill_repo_commits: "operations.backfill_repo_commits"]

      sidekiq_options retry: 3

      def perform(repo, clock)
        case backfill_repo_commits.call(repo, clock: Time.iso8601(clock))
          in Failure(:rate_limited) then reschedule(repo, clock)
          else nil
        end
      end

      private

      def reschedule(repo, clock) = self.class.perform_at(reschedule_at, repo, clock)

      def reschedule_at
        reset_at = client.rate_limit_reset_at
        soonest = Time.now + SOONEST_RETRY

        reset_at && reset_at > soonest ? reset_at : soonest
      end
    end
  end
end
