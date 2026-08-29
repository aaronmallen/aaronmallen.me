# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostPreview
      def call(values:, now: Time.now)
        body = Blog::Types::Text[values[:body]]

        {
          body_html: ::Posts::Markdown.to_html(body),
          read_time: ::Posts::Markdown.read_time(body),
          tags: Blog::Types::TagList[Blog::Types::Text[values[:tags]]],
          time: publish_at(values) || now,
          title: Blog::Types::Text[values[:title]].strip,
        }
      end

      private

      def publish_at(values)
        Blog::TimeZone.parse_input(Blog::Types::Text[values[:publish_at]])
      rescue TZInfo::PeriodNotFound
        nil
      end
    end
  end
end
