# frozen_string_literal: true

module API
  module Serializers
    class SocialDelivery < Serializer
      Entry = Data.define(:network, :delivery, :part_count)

      FAILED = "failed"
      RETRYING = "retrying"
      SENDING = "sending"
      SENT = "sent"
      WAITING = "waiting"
      STATES = [WAITING, SENDING, RETRYING, SENT, FAILED].freeze

      SCHEMA = Helpers::Schema.object(
        {
          network: { type: "string", enum: Blog::Types::NetworkName.values },
          state: { type: "string", enum: STATES, description: "waiting until the network has been tried" },
          url: Helpers::Schema.nullable({ type: "string", description: "the first part on the network, once sent" }),
          error: Helpers::Schema.nullable({ type: "string", description: "the last error the network gave" }),
          likes: Helpers::Schema::INTEGER,
          reposts: Helpers::Schema::INTEGER,
          replies: Helpers::Schema::INTEGER,
        },
      ).freeze

      schema_attributes

      def error(entry) = entry.delivery&.error

      def likes(entry) = entry.delivery&.like_count.to_i

      def replies(entry) = entry.delivery&.reply_count.to_i

      def reposts(entry) = entry.delivery&.repost_count.to_i

      def state(entry)
        delivery = entry.delivery
        return WAITING if delivery.nil?
        return FAILED if delivery.failed
        return SENT if delivery.remote_ids.to_a.length >= entry.part_count

        delivery.error ? RETRYING : SENDING
      end

      def url(entry) = entry.delivery&.remote_url
    end
  end
end
