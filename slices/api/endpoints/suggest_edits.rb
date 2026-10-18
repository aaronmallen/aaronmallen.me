# frozen_string_literal: true

module API
  module Endpoints
    class SuggestEdits < Endpoint
      FINDS = true
      FIRST_PART = 1
      LONG = "long"
      PENDING = Blog::Types::SuggestionEditStatus["pending"]
      PUBLISHED = "blog post %s is published; suggest edits only on a draft or scheduled post"

      CONTRACTS = [::Suggestions::Contracts::EditsContract].freeze
      COMPLAINTS = Helpers::Wording::SHARED.merge(
        Blog::Contract::BLANK => "needs a character that is not a space",
        LONG => "is too long",
      ).freeze

      EDIT = {
        type: "object",
        additionalProperties: false,
        properties: {
          original: {
            type: "string",
            minLength: 1,
            maxLength: Blog::Constants::SUGGESTION_TEXT_MAX,
            description: "the exact text to replace, copied from the body",
          },
          part: { type: "integer", minimum: 1, description: "which social post part, counting from 1" },
          reason: {
            type: "string",
            minLength: 1,
            maxLength: Blog::Constants::SUGGESTION_REASON_MAX,
            description: "a few words, such as typo or subject-verb agreement",
          },
          replacement: {
            type: "string",
            maxLength: Blog::Constants::SUGGESTION_TEXT_MAX,
            description: "the text that takes its place",
          },
        },
        required: %w[original replacement reason],
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          edits: { type: "array", items: EDIT, maxItems: Blog::Constants::SUGGESTION_EDITS_MAX },
          id: Helpers::Schema::ID,
          target: Suggestions::TARGET,
        },
        required: %w[target id edits],
      }.freeze

      REPLY = Helpers::Schema.object(
        {
          suggestion_id: Helpers::Schema::INTEGER,
          target: Suggestions::TARGET,
          edits: { type: "integer", description: "how many edits the set holds" },
          status: { type: "string", enum: [PENDING] },
        },
      ).freeze

      include Deps[
        post_queries: "posts.repos.post_queries",
        replace_post_edits: "suggestions.operations.replace_post_edits",
        replace_social_post_edits: "suggestions.operations.replace_social_post_edits",
        social_post_queries: "social.repos.social_post_queries",
      ]

      def handle(target:, id:, edits:)
        return invalid(edits: ["give at least one edit"]) if edits.empty?

        edits = edits.map { it.transform_keys(&:to_sym) }
        target == Suggestions::POST ? for_post(id, edits) : for_social_post(id, edits)
      end

      private

      def fault(index, field, code) = "edit #{index + 1}: #{field} #{Helpers::Wording.plain(code, COMPLAINTS)}"

      def faults(errors)
        errors.fetch(:edits).flat_map { |index, fields| fields.map { |field, (code)| fault(index, field, code) } }
      end

      def for_post(id, edits)
        return missing("blog post", id) if post_queries.by_id(id).nil?

        case replace_post_edits.call(id, edits: edits.map { it.except(:part) })
          in Failure(:published) then invalid(id: [format(PUBLISHED, id)])
          in result then stored(result, Suggestions::POST)
        end
      end

      def for_social_post(id, edits)
        social_post = social_post_queries.editable(id)
        return unsent_missing(id) if social_post.nil?

        numbered = edits.map { it.merge(part: it.fetch(:part, FIRST_PART)) }
        missing = missing_part(numbered, social_post.parts.length)
        return invalid(edits: ["social post #{id} has no part #{missing}"]) if missing

        case replace_social_post_edits.call(id, edits: numbered)
          in Failure(:already_posted) then unsent_missing(id)
          in result then stored(result, Suggestions::SOCIAL_POST)
        end
      end

      def missing_part(edits, count) = edits.map { it.fetch(:part) }.grep_v(FIRST_PART..count).first

      def stored(result, target)
        case result
          in Success(suggestion)
            Success(suggestion_id: suggestion.id, target:, edits: suggestion.edits.length, status: PENDING)
          in Failure[:invalid, errors] then invalid(edits: faults(errors))
          in unmatched then unhandled(unmatched, "could not store the edits")
        end
      end

      def unsent_missing(id) = missing("unsent social post", id)
    end
  end
end
