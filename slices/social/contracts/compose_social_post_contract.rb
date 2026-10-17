# frozen_string_literal: true

module Social
  module Contracts
    class ComposeSocialPostContract < Blog::Contract
      MODE = Blog::Types::SocialMode.constructor do |value|
        text = Blog::Types::TrimmedText[value]
        text.empty? ? Blog::Types::SocialMode["now"] : text
      end
      SCHEDULE = Blog::Types::SocialMode["schedule"]
      SEND = Blog::Types::SocialIntent["send"]
      SILENT_PART = "silent_part"
      UNAVAILABLE = "unavailable"

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
        optional(:photos).value(:array)
      end

      rule(:parts).validate(:without_controls, :visible, :known_mentions)

      rule(:photos) do
        next unless key?

        key.failure(SILENT_PART) if value.any? { it.is_a?(::Hash) && it[:part].nil? }
      end

      rule(:schedule_at, :mode).validate(moment: :scheduled?)

      rule(:schedule_at, :mode) do
        key.failure(FORMAT) if value.nil? && scheduled?(values)
      end

      rule(:targets) do
        key.failure(UNAVAILABLE) unless value.all? { networks.fetch(it).configured? }
      end

      rule(:parts, :targets) do |context:|
        next unless context[:intent] == SEND

        key(:parts).failure(TOO_LONG) unless check_network_fit.call(*values.values_at(:parts, :targets))
      end

      private

      def scheduled?(values, _context = nil) = values[:mode] == SCHEDULE
    end
  end
end
