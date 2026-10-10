# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeToday < Operation
      BACKFILL = Record::Jobs::BackfillRepoCommits.name
      COMMIT_LIMIT = 10
      COMMITS = Blog::Types::SyncName["commits"]
      COUNTRIES = "countries"
      DRAFT = Blog::Types::PostStatus["draft"]
      SUMMARY_LIMIT = 60

      include Deps[
        "operations.summarize_sprint",
        attention_queries: "activity.repos.attention_queries",
        client: "record.github.client",
        commit_queries: "record.repos.commit_queries",
        country_queries: "analytics.repos.country_queries",
        event_queries: "analytics.repos.analytics_event_queries",
        inbox_queries: "api.repos.inbox_queries",
        journal_entry_queries: "record.repos.journal_entry_queries",
        oauth_client_queries: "mcp.repos.oauth_client_queries",
        post_queries: "posts.repos.post_queries",
        social_post_queries: "social.repos.social_post_queries",
        sync_state_queries: "record.repos.sync_state_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call(now: Time.now, pool: nil)
        sprint = step summarize_sprint.call(now:, pool:)

        {
          **publishing(now),
          **counts(now),
          attention: attention(now),
          commits: commits(now),
          commit_totals: commit_queries.today_totals(now:),
          entries: journal_entry_queries.today(now:),
          sprint:,
        }
      end

      private

      def attention(now)
        failures = self.failures

        {
          rows: attention_queries.stalled(now:),
          failures:,
          dead_jobs: unshown(attention_queries.dead_jobs, failures),
          failed_social_posts: social_post_queries.failed_statuses,
          inbox: inbox_queries.unseen_count,
          webmentions: webmention_queries.pending_count,
        }
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
        { clients: oauth_client_queries.connected.size, visitors: event_queries.visitors_on(Blog::TimeZone.today(now)) }
      end

      def draft_counts(drafts)
        drafts.to_h { [it.id, { read_time: it.read_time, words: ::Posts::Markdown.word_count(it.body) }] }
      end

      def due(scheduled, social) = scheduled.map(&:published_at) + social[:scheduled].map(&:posted_at)

      def failures
        sync_state_queries.failures + [countries_failure].compact
      end

      def posts(scheduled)
        drafts = post_queries.by_status(DRAFT)

        { scheduled:, drafts:, draft_counts: draft_counts(drafts) }
      end

      def publishing(now)
        scheduled = post_queries.scheduled
        social = social_queue

        { posts: posts(scheduled), queue: queue(scheduled, social, now), social: }
      end

      def queue(scheduled, social, now)
        today = Blog::TimeZone.today(now)
        pending = due(scheduled, social)

        {
          count: pending.size,
          posts: scheduled.size,
          social_posts: social[:scheduled].size,
          today: pending.count { Blog::TimeZone.today(it) == today },
        }
      end

      def social_queue
        scheduled = social_post_queries.queued

        { scheduled:, summaries: scheduled.to_h { [it.id, summary(it)] } }
      end

      def summary(social_post)
        body = Blog::Helpers::Whitespace.squish(social_post.parts.first.body)

        Blog::Helpers::Truncation.cut(body, keep: SUMMARY_LIMIT)
      end

      def unshown(dead_jobs, failures)
        repos = failures.filter_map { it[:repo] if it[:sync] == COMMITS }

        dead_jobs.reject { it.name == BACKFILL && repos.include?(it.args.first) }
      end
    end
  end
end
