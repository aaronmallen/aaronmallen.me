# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeToday < Blog::Operation
      BACKFILL = Record::Repos::SyncStateQueries::BACKFILL_JOB
      COMMIT_LIMIT = 10
      COMMITS = Blog::Types::SyncName["commits"]
      COUNTRIES = "countries"
      DRAFT = Blog::Types::PostStatus["draft"]
      SCHEDULED = Blog::Types::PostStatus["scheduled"]
      SOCIAL_SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

      include Deps[
        "operations.summarize_sprint",
        agent_session_queries: "agents.repos.agent_session_queries",
        attention_queries: "activity.repos.attention_queries",
        client: "github.client",
        client_queries: "api.repos.client_queries",
        commit_queries: "record.repos.commit_queries",
        country_queries: "analytics.repos.country_queries",
        event_queries: "analytics.repos.analytics_event_queries",
        health_queries: "health.repos.health_queries",
        journal_entry_queries: "record.repos.journal_entry_queries",
        post_queries: "posts.repos.post_queries",
        short_link_queries: "shares.repos.short_link_queries",
        social_post_queries: "social.repos.social_post_queries",
        sync_state_queries: "record.repos.sync_state_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call(page:, inbox:, now: Time.now, pool: nil)
        sprint = step summarize_sprint.call(page:, now:, pool:)

        {
          **counts(now),
          agents: agent_session_queries.today_counts(now:),
          attention: attention(now, inbox),
          commits: commits(now),
          commit_totals: commit_queries.today_totals(now:),
          entries: journal_entry_queries.today(now:),
          last_night: last_night(now),
          link_check_run: post_queries.last_link_check_run,
          publishing:,
          sprint:,
        }
      end

      private

      def attention(now, inbox)
        failures = self.failures
        dead_jobs = attention_queries.dead_jobs

        {
          **attention_queries.capped(now:),
          broken_links:,
          failures:,
          dead_jobs: unshown(dead_jobs, failures),
          more_dead_jobs: attention_queries.dead_job_count - dead_jobs.size,
          failed_social_posts: social_post_queries.failed_statuses,
          inbox:,
          webmentions: webmention_queries.pending_count,
        }
      end

      def broken_links
        { posts: post_queries.link_check_tally[:links], short: short_link_queries.count_listed(failing: true) }
      end

      def commits(now)
        {
          entries: commit_queries.today(now:, limit: COMMIT_LIMIT),
          last_synced_at: commit_queries.last_synced_at,
          repos: commit_queries.today_repos(now:).size,
          today: Blog::TimeZone.today(now),
          configured: client.configured?,
        }
      end

      def countries_failure
        found = country_queries.database_failure

        { reason: found.to_s, repo: nil, sync: COUNTRIES } if found
      end

      def counts(now)
        { clients: client_queries.connected.size, visitors: event_queries.visitors_on(Blog::TimeZone.today(now)) }
      end

      def failures
        sync_state_queries.failures + [countries_failure].compact
      end

      def last_night(now)
        today = Blog::TimeZone.today(now)

        health_queries.days(from: today, to: today)[today]
      end

      def publishing
        posts = post_queries.count_by_status

        {
          drafts: posts.fetch(DRAFT, 0),
          queued: posts.fetch(SCHEDULED, 0) + social_post_queries.count_by_status.fetch(SOCIAL_SCHEDULED, 0),
          next_post: post_queries.next_scheduled,
          next_social_at: social_post_queries.next_queued_at,
        }
      end

      def unshown(dead_jobs, failures)
        repos = failures.filter_map { it[:repo] if it[:sync] == COMMITS }

        dead_jobs.reject { it.name == BACKFILL && repos.include?(it.args.first) }
      end
    end
  end
end
