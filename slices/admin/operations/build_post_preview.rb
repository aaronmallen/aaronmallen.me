# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostPreview
      def call(values:, now: Time.now, document: ::Markdown::Document.new(Blog::Types::Text[values[:body]]))
        {
          body_html: document.html,
          read_time: document.read_time,
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
