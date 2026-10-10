# frozen_string_literal: true

module Posts
  module Structs
    class Post < Blog::DB::Struct
      CARD = %i[og_title og_image_url canonical_url].freeze
      TAG_SEPARATOR = ", "
      UNCHECKED = "0"

      def body_html = document.html

      def canonical_url = written(:canonical_url)

      def changed_at = [published_at, updated_at].compact.max

      def form
        {
          title:,
          slug:,
          summary: written_summary.to_s,
          tags: tags.map(&:name).join(TAG_SEPARATOR),
          body:,
          publish_at:,
          **CARD.to_h { [it, public_send(it).to_s] },
          syndication_body:,
          syndication_enabled: syndication_enabled ? Blog::Constants::CHECKED : UNCHECKED,
          syndication_targets: syndication_targets.to_a,
        }
      end

      def headings = document.headings

      def og_image_url = written(:og_image_url)

      def og_title = written(:og_title)

      def read_time = document.read_time

      def summary = written_summary || document.first_paragraph

      def written_summary = written(:summary)

      private

      def document = @document ||= Markdown::Document.new(body)

      def publish_at = published_at ? Blog::TimeZone.input_value(published_at) : Blog::Constants::EMPTY_STRING

      def written(field)
        given = self[field].to_s.strip

        given unless given.empty?
      end
    end
  end
end
