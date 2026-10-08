# frozen_string_literal: true

module API
  module Serializers
    class Message < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          subject: Helpers::Schema::STRING,
          body: Helpers::Schema::STRING,
          reply_to: Helpers::Schema::STRING,
          status: { type: "string", enum: Blog::Types::MessageStatus.values },
          received_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :received_at
    end
  end
end
