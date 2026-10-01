# frozen_string_literal: true

module Posts
  module Structs
    class Post < Blog::DB::Struct
      def body_html = document.html

      def canonical_url = written(:canonical_url)

      def changed_at = [published_at, updated_at].compact.max

      def og_image_url = written(:og_image_url)

      def og_title = written(:og_title)

      def read_time = document.read_time

      def summary = written_summary || document.first_paragraph

      def written_summary = written(:summary)

      private

      def document = @document ||= Markdown::Document.new(body)

      def written(field)
        given = self[field].to_s.strip

        given unless given.empty?
      end
    end
  end
end
