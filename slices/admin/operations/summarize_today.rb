# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeToday < Blog::Operation
      COUNTRIES = "countries"
      DRAFT = Blog::Types::PostStatus["draft"]
      PENDING_MENTIONS = 3
      SUMMARY_LIMIT = 60

      include Deps[
        "operations.summarize_sprint",
        client: "record.github.client",
        commit_totals_today: "record.queries.commit_totals_today",
        commits_last_synced_at: "record.queries.commits_last_synced_at",
        commits_today: "record.queries.commits_today",
        country_database_failure: "analytics.queries.country_database_failure",
        journal_entries_today: "record.queries.journal_entries_today",
        pending_webmention_count: "social.queries.pending_webmention_count",
        pending_webmentions: "social.queries.pending_webmentions",
        posts_by_status: "posts.queries.by_status",
        queued_social_posts: "social.queries.queued_social_posts",
        recent_commit_repos: "record.queries.recent_commit_repos",
        scheduled_posts: "posts.queries.scheduled",
        sync_failures: "record.queries.sync_failures",
      ]

      def call(now: Time.now, pool: nil)
        scheduled = scheduled_posts.call
        social = social_queue
        sprint = step summarize_sprint.call(now:, pool:)

        {
          commits: commits(now),
          commit_totals: commit_totals_today.call(now:),
          entries: journal_entries_today.call(now:),
          posts: posts(scheduled),
          queue: queue(scheduled, social, now),
          social:,
          sprint:,
          sync_failures: failures,
          webmentions:,
        }
      end

      private

      def commits(now)
        {
          entries: commits_today.call(now:),
          last_synced_at: commits_last_synced_at.call,
          repos: recent_commit_repos.call(now:).size,
          today: Blog::TimeZone.today(now),
          configured: client.configured?,
        }
      end

      def countries_failure
        found = country_database_failure.call

        { reason: found.to_s, repo: nil, sync: COUNTRIES } if found
      end

      def draft_counts(drafts)
        drafts.to_h { [it.id, { read_time: it.read_time, words: ::Posts::Markdown.word_count(it.body) }] }
      end

      def due(scheduled, social) = scheduled.map(&:published_at) + social[:scheduled].map(&:posted_at)

      def failures
        sync_failures.call + [countries_failure].compact
      end

      def posts(scheduled)
        drafts = posts_by_status.call(DRAFT)

        { scheduled:, drafts:, draft_counts: draft_counts(drafts) }
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
