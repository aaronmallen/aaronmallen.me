# frozen_string_literal: true

module Admin
  module Operations
    class ListActivityEvents
      include Dry::Core::Constants

      COMMIT = Blog::Types::ActivityKind["commit"]
      JOURNAL = Blog::Types::ActivityKind["journal"]
      NAME_LIMIT = 120
      POST = Blog::Types::ActivityKind["post"]
      SHA_LENGTH = 7
      SOCIAL = Blog::Types::ActivityKind["social"]
      STATUSES = {
        Blog::Types::PostStatus["published"] => "activity_page.statuses.published",
        Blog::Types::SocialPostStatus["posted"] => "activity_page.statuses.posted",
      }.freeze
      TASK = Blog::Types::ActivityKind["task"]
      WEBMENTION = Blog::Types::ActivityKind["webmention"]

      include Deps[
        "i18n",
        activity_between: "activity.queries.activity_between",
        views_by_path: "analytics.queries.views_by_path",
      ]

      def call(from:, to:, types:, text:, repos: EMPTY_ARRAY, tags: EMPTY_ARRAY)
        rows = activity_between.call(from:, to:, types:, repos:, text:, tags:)
        views = rows.any? { it.type == POST } ? views_by_path.call : EMPTY_HASH

        rows.map { event(it, views) }
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
          sub_line: sub_line(row, views),
        )
      end

      def networks(targets)
        targets.to_a.map { i18n.t(Structs::Network::LABELS.fetch(it)) }.join(Structs::Network::SEPARATOR)
      end

      def post_line(row, views)
        i18n.t(
          "activity_page.sub_lines.post",
          link: row.link, status: status(row.status), views: view_count(row, views),
        )
      end

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
        when JOURNAL then i18n.t("activity_page.sub_lines.journal")
        when POST then post_line(row, views)
        when SOCIAL then social_line(row)
        when TASK then i18n.t("activity_page.sub_lines.task")
        when WEBMENTION then webmention_line(row)
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
