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
        expand_for_network: "operations.expand_for_network",
        networks: "networks.all",
        person_queries: "repos.person_queries",
      ]

      params do
        required(:parts).value(Blog::Types::TextList, :filled?)
        required(:targets).value(Blog::Types::Normalized::Networks, :filled?)
        required(:mode).value(MODE)
        required(:schedule_at).value(Blog::Types::LocalTime)
      end

      rule(:parts).validate(:without_controls, :visible)

      rule(:parts) do
        key.failure(UNKNOWN_MENTION) if person_queries.mention_directory(value).unknown(value).any?
      end

      rule(:schedule_at, :mode) do
        next unless values[:mode] == Blog::Types::SocialMode["schedule"]
        next if value.is_a?(Time)

        key.failure(value == Blog::Types::GAP ? SKIPPED : FORMAT)
      end

      rule(:targets) do
        key.failure(UNAVAILABLE) unless value.all? { networks.fetch(it).configured? }
      end

      rule(:parts, :targets) do |context:|
        next unless context[:intent] == SEND

        parts, targets = values.values_at(:parts, :targets)
        over = targets.any? do |name|
          expand_for_network.call(parts, name).any? { !networks.fetch(name).within_limit?(it.text) }
        end
        key(:parts).failure(TOO_LONG) if over
      end
    end
  end
end
