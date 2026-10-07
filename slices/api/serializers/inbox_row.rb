# frozen_string_literal: true

module API
  module Serializers
    class InboxRow < Serializer
      KINDS = %w[message webmention task].freeze

      SOURCE = Schema.object(
        {
          provider: { type: "string", enum: Blog::Types::TaskSourceProvider.values },
          reference: Schema.nullable({ type: "string", description: "the issue's short name, such as owner/repo#12" }),
        },
      ).freeze

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: Schema::INTEGER,
          at: Schema::STAMP,
          title: Schema::STRING,
          excerpt: Schema.nullable(Schema::STRING),
          url: Schema.nullable(Schema::STRING),
          tags: Schema.nullable(Schema::TAGS).merge(description: "a task's tags, or null for another kind"),
          source: Schema.nullable(SOURCE).merge(description: "the issue a task syncs from, or null for another kind"),
          type: Schema.nullable({ type: "string", enum: Blog::Types::WebmentionType.values })
                      .merge(description: "a webmention's type, or null for another kind"),
          post_id: Schema.nullable(Schema::INTEGER).merge(description: "a webmention's post, or null for another kind"),
          reply_to: Schema.nullable(Schema::STRING)
                          .merge(description: "a message's reply address, or null for another kind"),
        },
      ).freeze

      schema_attributes
      stamps :at

      def excerpt(row)
        case row.kind
          when :message then row.record.body
          when :webmention then row.record.excerpt
        end
      end

      def id(row) = row.record.id

      def kind(row) = row.kind.to_s

      def post_id(row)
        row.record.post_id if row.kind == :webmention
      end

      def reply_to(row)
        row.record.reply_to if row.kind == :message
      end

      def source(row)
        return unless row.kind == :task

        found = row.record.source
        { provider: found.provider, reference: ::Tasks::SourceReference.for(found).name }
      end

      def tags(row)
        tag_names(row.record) if row.kind == :task
      end

      def title(row)
        case row.kind
          when :message then row.record.subject
          when :webmention then row.record.author_label
          else row.record.title
        end
      end

      def type(row)
        row.record.type if row.kind == :webmention
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
