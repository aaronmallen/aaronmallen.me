# frozen_string_literal: true

module Admin
  module Operations
    class ListActivityEvents
      include Blog::Constants

      COMMENT = Blog::Types::ActivityKind["comment"]
      COMMIT = Blog::Types::ActivityKind["commit"]
      DECISION = Blog::Types::ActivityKind["decision"]
      DECISION_COMMENT = Blog::Types::ActivityKind["decision_comment"]
      DECISION_EVENTS = "activity_page.decision_events"
      JOURNAL = Blog::Types::ActivityKind["journal"]
      TASK = Blog::Types::ActivityKind["task"]
      LINES = {
        COMMENT => "activity_page.sub_lines.comment",
        JOURNAL => "activity_page.sub_lines.journal",
        **Blog::Types::ActivityKind.values.grep(/\Apull_request_/).to_h { [it, "activity_page.sub_lines.#{it}"] },
      }.freeze
      MARKDOWN = [JOURNAL, COMMENT, DECISION_COMMENT].freeze
      NAME_LIMIT = 120
      OCCURRED_ON = :occurred_on.to_proc
      POST = Blog::Types::ActivityKind["post"]
      SESSION = Blog::Types::ActivityKind["session"]
      SHA_LENGTH = 7
      SOCIAL = Blog::Types::ActivityKind["social"]
      STATUSES = {
        Blog::Types::PostStatus["published"] => "activity_page.statuses.published",
        Blog::Types::SocialPostStatus["posted"] => "activity_page.statuses.posted",
      }.freeze
      WEBMENTION = Blog::Types::ActivityKind["webmention"]
      LINE_BUILDERS = {
        COMMIT => :commit_line,
        DECISION => :decision_line,
        DECISION_COMMENT => :decision_comment_line,
        SESSION => :session_line,
        SOCIAL => :social_line,
        TASK => :task_line,
        WEBMENTION => :webmention_line,
      }.freeze

      include Deps[
        "i18n",
        activity_queries: "activity.repos.activity_queries",
        rollup_queries: "analytics.repos.analytics_rollup_queries",
      ]

      def call(from:, day:, size:, **filters)
        found = page(from, day, size, filters)
        views = found.rows.any? { it.type == POST } ? rollup_queries.views_by_path : EMPTY_HASH

        found.with(rows: found.rows.map { event(it, views) })
      end

      def newer_day(from:, to:, day:, size:, **filters)
        return if day >= to

        counts = activity_queries.counts_by_day(from: day, to:, **filters)
        starts = page_starts(counts, to:, day:, size:)
        return starts.last if shows_rows?(starts.last, counts:, to:, from:, day:, filters:)

        starts[-2]
      end

      private

      def commit_line(row)
        i18n.t!(
          "activity_page.sub_lines.commit",
          repo: row.repo, sha: row.sha.to_s[0, SHA_LENGTH], additions: row.additions, deletions: row.deletions,
        )
      end

      def decision_comment_line(row) = i18n.t!("activity_page.sub_lines.decision_comment", decision: row.excerpt)

      def decision_line(row)
        event = i18n.t!(row.status, scope: DECISION_EVENTS)
        return i18n.t!("activity_page.sub_lines.decision", event:) unless row.excerpt

        i18n.t!("activity_page.sub_lines.decision_excerpt", event:, excerpt: shortened(row.excerpt))
      end

      def display_name(row) = row.type == COMMIT ? Helpers::CommitMessage.subject(row.name) : row.name

      def event(row, views)
        Structs::ActivityEvent.new(
          type: row.type,
          source_id: row.source_id,
          occurred_on: row.occurred_on,
          occurred_at: row.occurred_at,
          name: shortened(display_name(row)),
          name_html: name_html(row),
          sub_line: sub_line(row, views),
          task_id: row.task_id,
          decision_id: row.decision_id,
        )
      end

      def name_html(row)
        InlineMarkdown.to_html(row.name, keep: NAME_LIMIT) if MARKDOWN.include?(row.type)
      end

      def networks(targets)
        targets.to_a.map { i18n.t!(Structs::Network::LABELS.fetch(it)) }.join(Structs::Network::SEPARATOR)
      end

      def page(from, to, size, filters)
        Blog::Structs::DayCursor.page(from, to, size:, day: OCCURRED_ON) do |first, last, limit|
          activity_queries.between(from: first, to: last, limit:, **filters)
        end
      end

      def page_ends(counts, size)
        seen = 0

        counts.each_with_object([]) do |(date, count), ends|
          seen += count
          next if seen < size

          ends << date
          seen = 0
        end
      end

      def page_starts(counts, to:, day:, size:)
        [to, *page_ends(counts, size).map(&:prev_day)].select { it > day }
      end

      def post_line(row, views)
        i18n.t!(
          "activity_page.sub_lines.post",
          link: row.link, status: status(row.status), views: view_count(row, views),
        )
      end

      def rows_before?(from, day, filters) = activity_queries.between(from:, to: day.prev_day, limit: 1, **filters).any?

      def session_line(row)
        i18n.t!("activity_page.sub_lines.session", span: Blog::Helpers::Figures.hours(row.worked_seconds))
      end

      def shortened(name)
        Blog::Helpers::Truncation.cut(Blog::Helpers::Whitespace.squish(Blog::Types::Text[name]), keep: NAME_LIMIT)
      end

      def shows_rows?(start, counts:, to:, from:, day:, filters:)
        start == to || counts.keys.min <= start || rows_before?(from, day, filters)
      end

      def social_line(row)
        i18n.t!("activity_page.sub_lines.social", status: status(row.status), networks: networks(row.targets))
      end

      def status(value) = i18n.t!(STATUSES.fetch(value))

      def sub_line(row, views)
        return post_line(row, views) if row.type == POST

        builder = LINE_BUILDERS[row.type]
        builder ? send(builder, row) : i18n.t!(LINES.fetch(row.type), task: row.excerpt, repo: row.repo)
      end

      def task_line(row)
        contributors = Helpers::Credits.words(row.contributors) { |key, **words| i18n.t!(key, **words) }

        i18n.t!("activity_page.sub_lines.task", contributors:)
      end

      def view_count(row, views) = i18n.t!("activity_page.views", count: views.fetch(row.link, 0))

      def webmention_line(row)
        return i18n.t!("activity_page.sub_lines.webmention", link: row.link) unless row.excerpt

        i18n.t!("activity_page.sub_lines.webmention_excerpt", link: row.link, excerpt: row.excerpt)
      end
    end
  end
end
