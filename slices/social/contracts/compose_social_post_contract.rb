# frozen_string_literal: true

module Social
  module Contracts
    class ComposeSocialPostContract < Blog::Contract
      MODE = Blog::Types::SocialMode.constructor do |value|
        text = Blog::Types::TrimmedText[value]
        text.empty? ? Blog::Types::SocialMode["now"] : text
      end
      SEND = Blog::Types::SocialIntent["send"]
      TOO_LONG = "too_long"
      UNAVAILABLE = "unavailable"
      UNKNOWN_MENTION = "unknown_mention"

      include Deps[
        check_network_fit: "operations.check_network_fit",
        networks: "networks.all",
        resolve_mentions: "operations.resolve_mentions",
      ]

      params do
        required(:parts).value(Blog::Types::TextList, :filled?)
        required(:targets).value(Blog::Types::Normalized::Networks, :filled?)
        optional(:connection_ids).value(Blog::Types::IdList)
        required(:mode).value(MODE)
        required(:schedule_at).value(Blog::Types::LocalTime)
      end

      rule(:parts).validate(:without_controls, :visible)

      rule(:parts) do
        key.failure(UNKNOWN_MENTION) if resolve_mentions.unknown(value).any?
      end

      rule(:schedule_at, :mode) do
        next unless values[:mode] == Blog::Types::SocialMode["schedule"]
        next if value.is_a?(Time)

        key.failure(value == Blog::Constants::GAP ? SKIPPED : FORMAT)
      end

      rule(:targets) do
        key.failure(UNAVAILABLE) unless value.all? { networks.fetch(it).configured? }
      end

      rule(:parts, :targets) do |context:|
        next unless context[:intent] == SEND

        key(:parts).failure(TOO_LONG) unless check_network_fit.call(*values.values_at(:parts, :targets))
      end
    end
  end
end
