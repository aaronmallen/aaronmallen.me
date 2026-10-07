# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeToday < Operation
      COMMIT_LIMIT = 10
      COUNTRIES = "countries"
      DRAFT = Blog::Types::PostStatus["draft"]
      PENDING_MENTIONS = 3
      SUMMARY_LIMIT = 60

      include Deps[
        "operations.summarize_sprint",
        attention_queries: "activity.repos.attention_queries",
        client: "record.github.client",
        commit_queries: "record.repos.commit_queries",
        country_queries: "analytics.repos.country_queries",
        event_queries: "analytics.repos.analytics_event_queries",
        journal_entry_queries: "record.repos.journal_entry_queries",
        pending_webmention_count: "social.queries.pending_webmention_count",
        pending_webmentions: "social.queries.pending_webmentions",
        posts_by_status: "posts.queries.by_status",
        queued_social_posts: "social.queries.queued_social_posts",
        scheduled_posts: "posts.queries.scheduled",
        sync_state_queries: "record.repos.sync_state_queries",
      ]

      def call(now: Time.now, pool: nil)
        sprint = step summarize_sprint.call(now:, pool:)

        {
          **publishing(now),
          attention: attention(now),
          commits: commits(now),
          commit_totals: commit_queries.today_totals(now:),
          entries: journal_entry_queries.today(now:),
          sprint:,
          sync_failures: failures,
          visitors: event_queries.visitors_on(Blog::TimeZone.today(now)),
          webmentions:,
        }
      end

      private

      def attention(now) = attention_queries.stalled(now:)

      def commits(now)
        {
          entries: commit_queries.today(now:, limit: COMMIT_LIMIT),
          last_synced_at: commit_queries.last_synced_at,
          repos: commit_queries.recent_repos(now:).size,
          today: Blog::TimeZone.today(now),
          configured: client.configured?,
        }
      end

      def countries_failure
        found = country_queries.database_failure

        { reason: found.to_s, repo: nil, sync: COUNTRIES } if found
      end

      def draft_counts(drafts)
        drafts.to_h { [it.id, { read_time: it.read_time, words: ::Posts::Markdown.word_count(it.body) }] }
      end

      def due(scheduled, social) = scheduled.map(&:published_at) + social[:scheduled].map(&:posted_at)

      def failures
        sync_state_queries.failures + [countries_failure].compact
      end

      def posts(scheduled)
        drafts = posts_by_status.call(DRAFT)

        { scheduled:, drafts:, draft_counts: draft_counts(drafts) }
      end

      def publishing(now)
        scheduled = scheduled_posts.call
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
        scheduled = queued_social_posts.call

        { scheduled:, summaries: scheduled.to_h { [it.id, summary(it)] } }
      end

      def summary(social_post)
        body = Blog::Whitespace.squish(social_post.parts.first.body)

        Blog::Truncation.cut(body, keep: SUMMARY_LIMIT)
      end

      def webmentions
        { count: pending_webmention_count.call, mentions: pending_webmentions.call(limit: PENDING_MENTIONS) }
      end
    end
  end
end
