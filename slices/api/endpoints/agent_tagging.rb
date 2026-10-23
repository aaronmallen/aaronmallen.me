# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class AgentTagging < Endpoint
      REPLIES = { session: Serializers::AgentSession, "memory file": Serializers::MemoryFile }.freeze
      TAG = {
        type: "string",
        description:
          "one tag, #{Helpers::Tags::FORMAT}; on a record in a project it is that project's own tag, made there " \
          "when missing, and on any other a private tag",
      }.freeze
      UNTAG = { type: "string", description: "the tag to take off" }.freeze

      private

      def replied(noun, id, result)
        case result
          in Success(record) then Success(serialized(REPLIES.fetch(noun), record))
          in Failure(:not_found) then missing(noun.to_s, id)
        end
      end

      def tagged(noun, id, tag)
        name = Blog::Types::Nullable::Tag[tag]
        return invalid(tag: [Helpers::Tags::COMPLAINTS.fetch(Blog::Contract::BLANK)]) if name.nil?
        return invalid(tag: [Helpers::Tags::REFUSAL]) unless Blog::Types::Tag.valid?(name)

        replied(noun, id, yield(name))
      end

      def untagged(noun, id, record, tag)
        return missing(noun.to_s, id) if record.nil?

        name = Blog::Types::TagList[tag].first
        return not_found("#{noun} #{id} has no tag #{tag}") unless record.tags.map(&:name).include?(name)

        replied(noun, id, yield(name))
      end
    end
  end
end
