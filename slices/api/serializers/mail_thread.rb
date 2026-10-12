# frozen_string_literal: true

module API
  module Serializers
    class MailThread < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          account: { type: "string", description: "the name of the account the thread came in on" },
          subject: Helpers::Schema::STRING,
          body: { type: "string", description: "the first message's body" },
          reply_to: { type: "string", description: "the first message's reply address" },
          status: { type: "string", enum: Blog::Types::MessageStatus.values },
          tags: Helpers::Schema::TAGS,
          received_at: Helpers::Schema::STAMP,
          snoozed_until: Helpers::Schema.nullable(Helpers::Schema::STAMP),
        },
      ).freeze

      schema_attributes
      stamps :received_at, :snoozed_until
      tag_names
    end
  end
end
