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

      include Deps[networks: "networks.all"]

      params do
        required(:parts).value(Blog::Types::TextList, :filled?)
        required(:targets).value(Blog::Types::Normalized::Networks, :filled?)
        required(:mode).value(MODE)
        required(:schedule_at).value(Blog::Types::LocalTime)
      end

      rule(:parts).validate(:without_controls)

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
        over = targets.any? { |name| parts.any? { |body| !networks.fetch(name).within_limit?(body) } }
        key(:parts).failure(TOO_LONG) if over
      end
    end
  end
end
