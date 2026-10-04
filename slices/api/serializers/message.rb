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

      attributes :id, :subject, :body, :reply_to, :status, :received_at

      def received_at(message) = stamp(message.received_at)
    end
  end
end
