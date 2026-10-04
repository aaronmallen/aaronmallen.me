# frozen_string_literal: true

module API
  module Serializers
    class InboxRow < Serializer
      KINDS = %w[message webmention task].freeze

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: Schema::INTEGER,
          at: Schema::STAMP,
          title: Schema::STRING,
          excerpt: Schema.nullable(Schema::STRING),
          url: Schema.nullable(Schema::STRING),
        },
      ).freeze

      attributes :kind, :id, :at, :title, :excerpt, :url

      def at(row) = stamp(row.at)

      def excerpt(row)
        case row.kind
        when :message then row.record.body
        when :webmention then row.record.excerpt
        end
      end

      def id(row) = row.record.id

      def kind(row) = row.kind.to_s

      def title(row)
        case row.kind
        when :message then row.record.subject
        when :webmention then row.record.author_label
        else row.record.title
        end
      end

      def url(row)
        case row.kind
        when :webmention then row.record.source_url
        when :task then row.record.source.url
        end
      end
    end
  end
end
