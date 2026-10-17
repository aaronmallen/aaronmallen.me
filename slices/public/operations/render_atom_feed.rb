# frozen_string_literal: true

require "builder"

module Public
  module Operations
    class RenderAtomFeed
      HTML_TYPE = "text/html"
      LANGUAGE = "en"
      MEDIA_TYPE = "application/atom+xml"
      NAMESPACE = "http://www.w3.org/2005/Atom"
      NO_EDITS = Blog::Constants::EMPTY_ARRAY
      REF = "feed"

      include Deps[
        "i18n", "routes", "settings",
        feed_queries: "posts.repos.feed_queries",
        post_queries: "posts.repos.post_queries",
        tag_ref: "analytics.operations.tag_ref",
      ]

      def call(version, title:, html:, feed:, params: {})
        xml = Builder::XmlMarkup.new(indent: 2)
        xml.instruct!(:xml, version: "1.0", encoding: "UTF-8")
        xml.feed(xmlns: NAMESPACE, "xml:lang": LANGUAGE) do
          feed_head(xml, version, title:, html:, params:)
          feed_links(xml, version.posts, html:, feed:, params:)
          feed_entries(xml, version)
        end
      end

      private

      def edit_day(html, day, edits)
        html.div(class: "post-edit") do
          html.p(class: "post-edit-date") do
            html.text!("#{i18n.t('ui.components.posts.edits.edited')} ")
            html.time(i18n.l(day, format: :medium), datetime: Blog::TimeZone.local(edits.last.created_at).iso8601)
          end
          html.text!(" ")
          edit_notes(html, edits)
        end
      end

      def edit_notes(html, edits)
        return html.div(class: "post-edit-note") { html << edits.first.note_html } if edits.one?

        html.ul(class: "post-edit-list") do
          edits.each { |edit| html.li(class: "post-edit-item") { html << edit.note_html } }
        end
      end

      def entry(xml, row, post, changed_at, edits)
        url = routes.url(:post, slug: post.slug).to_s

        xml.entry do
          xml.id(url)
          xml.title(post.title)
          entry_link(xml, url)
          entry_dates(xml, row.published_at, changed_at)
          row.tags.each { xml.category(term: it.name) }
          entry_body(xml, post, edits)
        end
      end

      def entry_body(xml, post, edits)
        summary = post.summary
        xml.summary(summary) if summary
        xml.content(post.body_html + notes(edits.fetch(post.id, NO_EDITS)), type: "html")
      end

      def entry_dates(xml, published_at, changed_at)
        xml.published(timestamp(published_at))
        xml.updated(timestamp(changed_at))
      end

      def entry_link(xml, url) = xml.link(rel: "alternate", type: HTML_TYPE, href: tag_ref.call(url, REF))

      def feed_entries(xml, version)
        rows = version.posts.rows
        ids = rows.map(&:id)
        edits = post_queries.edits_for_posts(ids)
        posts = feed_queries.entries(ids)
        rows.each { |row| posts[row.id]&.then { entry(xml, row, it, version.changed_at(row), edits) } }
      end

      def feed_head(xml, version, title:, html:, params:)
        xml.id(url(html, params))
        xml.title(title)
        xml.updated(timestamp(version.updated || Time.now))
        xml.author { xml.name(settings.owner_name) }
      end

      def feed_links(xml, posts, html:, feed:, params:)
        xml.link(rel: "alternate", type: HTML_TYPE, href: url(html, params, posts.number))
        xml.link(rel: "self", type: MEDIA_TYPE, href: url(feed, params, posts.number))
        { "next" => posts.next_number, "previous" => posts.previous_number }.each do |rel, number|
          xml.link(rel:, type: MEDIA_TYPE, href: url(feed, params, number)) if number
        end
      end

      def notes(edits)
        return Blog::Constants::EMPTY_STRING if edits.empty?

        html = Builder::XmlMarkup.new
        html.section(class: "post-edits", "aria-label": i18n.t("ui.components.posts.edits.label")) do
          Helpers::EditDays.newest_first(edits).each { |day, day_edits| edit_day(html, day, day_edits) }
        end
      end

      def timestamp(time) = time.utc.iso8601

      def url(route, params, number = 1) = routes.url(route, **params, **Blog::Structs::Page.query(number)).to_s
    end
  end
end
