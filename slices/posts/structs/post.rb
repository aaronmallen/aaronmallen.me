# frozen_string_literal: true

module Posts
  module Structs
    class Post < Blog::DB::Struct
      def canonical_url = written(:canonical_url)

      def changed_at = [published_at, updated_at].compact.max

      def og_image_url = written(:og_image_url)

      def og_title = written(:og_title)

      def read_time = @read_time ||= Markdown.read_time(body)

      def summary = written_summary || Markdown.first_paragraph(body)

      def written_summary = written(:summary)

      private

      def written(field)
        given = self[field].to_s.strip

        given unless given.empty?
      end
    end
  end
end
