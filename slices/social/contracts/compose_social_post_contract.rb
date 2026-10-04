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
        link_tagger: "links.tagger",
        mention_directory: "queries.mention_directory",
        networks: "networks.all",
      ]

      params do
        required(:parts).value(Blog::Types::TextList, :filled?)
        required(:targets).value(Blog::Types::Normalized::Networks, :filled?)
        required(:mode).value(MODE)
        required(:schedule_at).value(Blog::Types::LocalTime)
      end

      rule(:parts).validate(:without_controls, :visible)

      rule(:parts) do
        key.failure(UNKNOWN_MENTION) if mention_directory.call(value).unknown(value).any?
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

        parts, targets = values.values_at(:parts, :targets)
        directory = mention_directory.call(parts)
        over = targets.any? do |name|
          parts.any? do |body|
            !networks.fetch(name).within_limit?(directory.expand(link_tagger.call(body, name), name).text)
          end
        end
        key(:parts).failure(TOO_LONG) if over
      end
    end
  end
end
