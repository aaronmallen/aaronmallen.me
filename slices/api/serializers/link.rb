# frozen_string_literal: true

module API
  module Serializers
    class Link < Serializer
      KINDS = (Blog::Types::RecordKind.values - [Blog::Types::RecordKind["mail_thread"]]).freeze
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
    end
  end
end
