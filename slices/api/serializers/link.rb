# frozen_string_literal: true

module API
  module Serializers
    class Link < Serializer
      AGENT_KINDS = %w[memory_file artifact].map { Blog::Types::RecordKind[it] }.freeze
      COMMIT = Blog::Types::RecordKind["commit"]
      PULL_REQUEST = Blog::Types::RecordKind["pull_request"]
      TASK = Blog::Types::RecordKind["task"]
      MAIL_THREAD = Blog::Types::RecordKind["mail_thread"]
      KINDS = Blog::Types::RecordKind.values.freeze
      UNMAILED = (KINDS - [MAIL_THREAD]).freeze
      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          day: Helpers::Schema.nullable(Helpers::Schema::DAY),
          url: Helpers::Schema.nullable({ type: "string", description: "the record's page in the admin" }),
        },
      ).freeze

      GROUPS = Helpers::Schema.object(
        {},
        optional: KINDS.to_h { [it.to_sym, Helpers::Schema.list(reference)] },
      ).freeze

      schema_attributes

      def day(link) = super(link.day)

      def title(link)
        case link.kind
          when TASK then synced(link.id, link.title)
          when COMMIT, PULL_REQUEST, MAIL_THREAD, *AGENT_KINDS then untrusted(link.title)
          else link.title
        end
      end
    end
  end
end
