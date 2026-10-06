# frozen_string_literal: true

module API
  module Serializers
    class Message < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          subject: Schema::STRING,
          body: Schema::STRING,
          reply_to: Schema::STRING,
          status: { type: "string", enum: Blog::Types::MessageStatus.values },
          received_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :received_at
    end
  end
end
