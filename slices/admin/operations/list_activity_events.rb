# frozen_string_literal: true

module Admin
  module Operations
    class ListActivityEvents
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
      POST = Blog::Types::ActivityKind["post"]
      SESSION = Blog::Types::ActivityKind["session"]
      SOCIAL = Blog::Types::ActivityKind["social"]
      STATUSES = {
        Blog::Types::PostStatus["published"] => "activity_page.statuses.published",
        Blog::Types::SocialPostStatus["posted"] => "activity_page.statuses.posted",
      }.freeze
      WEBMENTION = Blog::Types::ActivityKind["webmention"]
      WORKOUT = Blog::Types::ActivityKind["workout"]

      include Blog::UI::Wording
      include Deps[
        "i18n",
        activity_queries: "activity.repos.activity_queries",
      ]

      def call(from:, to:, day:, size:, **filters)
        counts = activity_queries.counts_by_day(from:, to:, **filters)
        pages = Helpers::DayPages.call(counts, day:, to:, size:)
        rows = activity_queries.between(from: pages[:start] || from, to: day, **filters)
        views = activity_queries.views(rows)

        { events: rows.map { event(it, views) }, older: pages[:older], newer: pages[:newer], days: counts.size }
      end

      private

      def commit_line(row)
        i18n.t!(
          "activity_page.sub_lines.commit",
          repo: row.repo, sha: Helpers::Short.sha(row.sha), additions: row.additions, deletions: row.deletions,
        )
      end

      def decision_comment_line(row) = i18n.t!("activity_page.sub_lines.decision_comment", decision: row.excerpt)

      def decision_line(row)
        event = i18n.t!(row.status, scope: DECISION_EVENTS)
        return i18n.t!("activity_page.sub_lines.decision", event:) unless row.excerpt

        i18n.t!("activity_page.sub_lines.decision_excerpt", event:, excerpt: shortened(row.excerpt))
      end

      def display_name(row) = row.type == COMMIT ? Helpers::CommitMessage.subject(row.name) : row.preview || row.name

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

      def hours(seconds) = Blog::Helpers::Figures.hours(seconds)

      def name_html(row)
        InlineMarkdown.to_html(row.preview, keep: NAME_LIMIT) if MARKDOWN.include?(row.type)
      end

      def networks(targets)
        targets.to_a.map { i18n.t!(Structs::Network::LABELS.fetch(it)) }.join(Structs::Network::SEPARATOR)
      end

      def post_line(row, views)
        i18n.t!(
          "activity_page.sub_lines.post",
          link: row.link, status: status(row.status), views: view_count(row, views),
        )
      end

      def session_line(row) = i18n.t!("activity_page.sub_lines.session", span: hours(row.worked_seconds))

      def shortened(name)
        Blog::Helpers::Truncation.cut(Blog::Helpers::Whitespace.squish(Blog::Types::Text[name]), keep: NAME_LIMIT)
      end

      def social_line(row)
        i18n.t!("activity_page.sub_lines.social", status: status(row.status), networks: networks(row.targets))
      end

      def status(value) = i18n.t!(STATUSES.fetch(value))

      def sub_line(row, views)
        case row.type
          when POST then post_line(row, views)
          when DECISION_COMMENT then decision_comment_line(row)
          when SESSION then session_line(row)
          when *LINES.keys then i18n.t!(LINES.fetch(row.type), task: row.excerpt, repo: row.repo)
          else worded_line(row)
        end
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

      def worded_line(row)
        case row.type
          when COMMIT then commit_line(row)
          when DECISION then decision_line(row)
          when SOCIAL then social_line(row)
          when TASK then task_line(row)
          when WEBMENTION then webmention_line(row)
          when WORKOUT then workout_line(row)
        end
      end

      def workout_line(row) = dotted(hours(row.worked_seconds), row.excerpt)
    end
  end
end
