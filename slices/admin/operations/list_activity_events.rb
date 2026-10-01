# frozen_string_literal: true

module Admin
  module Operations
    class ListActivityEvents
      include Blog::Constants

      COMMENT = Blog::Types::ActivityKind["comment"]
      COMMIT = Blog::Types::ActivityKind["commit"]
      JOURNAL = Blog::Types::ActivityKind["journal"]
      TASK = Blog::Types::ActivityKind["task"]
      LINES = {
        COMMENT => "activity_page.sub_lines.comment",
        JOURNAL => "activity_page.sub_lines.journal",
        TASK => "activity_page.sub_lines.task",
      }.freeze
      MARKDOWN = [JOURNAL, COMMENT].freeze
      NAME_LIMIT = 120
      OCCURRED_ON = :occurred_on.to_proc
      POST = Blog::Types::ActivityKind["post"]
      SHA_LENGTH = 7
      SOCIAL = Blog::Types::ActivityKind["social"]
      STATUSES = {
        Blog::Types::PostStatus["published"] => "activity_page.statuses.published",
        Blog::Types::SocialPostStatus["posted"] => "activity_page.statuses.posted",
      }.freeze
      WEBMENTION = Blog::Types::ActivityKind["webmention"]

      include Deps[
        "i18n",
        activity_between: "activity.queries.activity_between",
        activity_counts_by_day: "activity.queries.activity_counts_by_day",
        views_by_path: "analytics.queries.views_by_path",
      ]

      def call(from:, day:, size:, **filters)
        found = page(from, day, size, filters)
        views = found.rows.any? { it.type == POST } ? views_by_path.call : EMPTY_HASH

        found.with(rows: found.rows.map { event(it, views) })
      end

      def newer_day(from:, to:, day:, size:, **filters)
        return if day >= to

        counts = activity_counts_by_day.call(from: day, to:, **filters)
        starts = [to, *page_ends(counts, size).map(&:prev_day)].select { it > day }
        last = starts.last

        last == to || counts.keys.min <= last || rows_before?(from, day, filters) ? last : starts[-2]
      end

      private

      def commit_line(row)
        i18n.t(
          "activity_page.sub_lines.commit",
          repo: row.repo, sha: row.sha.to_s[0, SHA_LENGTH], additions: row.additions, deletions: row.deletions,
        )
      end

      def display_name(row) = row.type == COMMIT ? CommitMessage.subject(row.name) : row.name

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
        )
      end

      def name_html(row)
        InlineMarkdown.to_html(row.name, keep: NAME_LIMIT) if MARKDOWN.include?(row.type)
      end

      def networks(targets)
        targets.to_a.map { i18n.t(Structs::Network::LABELS.fetch(it)) }.join(Structs::Network::SEPARATOR)
      end

      def page(from, to, size, filters)
        Blog::DayCursor.page(from, to, size:, day: OCCURRED_ON) do |first, last, limit|
          activity_between.call(from: first, to: last, limit:, **filters)
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

      def post_line(row, views)
        i18n.t(
          "activity_page.sub_lines.post",
          link: row.link, status: status(row.status), views: view_count(row, views),
        )
      end

      def rows_before?(from, day, filters) = activity_between.call(from:, to: day.prev_day, limit: 1, **filters).any?

      def shortened(name)
        squished = Blog::Whitespace.squish(Blog::Types::Text[name])

        Blog::Truncation.cut(squished, keep: NAME_LIMIT)
      end

      def social_line(row)
        i18n.t("activity_page.sub_lines.social", status: status(row.status), networks: networks(row.targets))
      end

      def status(value) = i18n.t(STATUSES.fetch(value))

      def sub_line(row, views)
        case row.type
        when COMMIT then commit_line(row)
        when POST then post_line(row, views)
        when SOCIAL then social_line(row)
        when WEBMENTION then webmention_line(row)
        else i18n.t(LINES.fetch(row.type), task: row.excerpt)
        end
      end

      def view_count(row, views) = i18n.t("activity_page.views", count: views.fetch(row.link, 0))

      def webmention_line(row)
        return i18n.t("activity_page.sub_lines.webmention", link: row.link) unless row.excerpt

        i18n.t("activity_page.sub_lines.webmention_excerpt", link: row.link, excerpt: row.excerpt)
      end
    end
  end
end
