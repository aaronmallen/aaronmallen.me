# frozen_string_literal: true

module MCP
  module Tools
    class SuggestEdits < Base
      FIRST_PART = 1
      LONG = "long"
      POST = "post"
      PUBLISHED = "blog post %s is published; suggest edits only on a draft or scheduled post"
      SOCIAL_POST = "social_post"
      UNSTORED = "could not store the edits"

      COMPLAINTS = {
        Blog::Contract::BLANK => "needs a character that is not a space",
        Blog::Contract::CONTROL => Complaints::CONTROL,
        LONG => "is too long",
      }.freeze

      EDIT = {
        type: "object",
        additionalProperties: false,
        properties: {
          original: {
            type: "string",
            minLength: 1,
            maxLength: ::Suggestions::Types::MAX_TEXT,
            description: "the exact text to replace, copied from the body",
          },
          part: { type: "integer", minimum: 1, description: "which social post part, counting from 1" },
          reason: {
            type: "string",
            minLength: 1,
            maxLength: ::Suggestions::Types::MAX_REASON,
            description: "a few words, such as typo or subject-verb agreement",
          },
          replacement: {
            type: "string",
            maxLength: ::Suggestions::Types::MAX_TEXT,
            description: "the text that takes its place",
          },
        },
        required: %w[original replacement reason],
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          edits: { type: "array", items: EDIT, maxItems: ::Suggestions::Types::MAX_EDITS },
          id: API::Schema::ID,
          target: { type: "string", enum: [POST, SOCIAL_POST] },
        },
        required: %w[target id edits],
      }.freeze

      description "Suggest grammar and spelling edits for one draft or scheduled blog post or unsent social " \
                  "post; they wait for the author to accept or reject and change nothing on their own, " \
                  "and a new set replaces the edits still waiting on that post"
      input_schema(SCHEMA)
      scope OAuth::Scope::SUGGEST

      class << self
        def call(target:, id:, edits:, server_context:)
          return refuse("give at least one edit") if edits.empty?
          return for_post(id, edits, server_context) if target == POST

          for_social_post(id, edits, server_context)
        end

        private

        def complaint(errors)
          faults = errors.fetch(:edits)
          faults.flat_map { |index, fields| fields.map { |field, (token)| fault(index, field, token) } }.join("; ")
        end

        def fault(index, field, token) = "edit #{index + 1}: #{field} #{COMPLAINTS.fetch(token, token)}"

        def for_post(id, edits, server_context)
          return refuse(API::Wording.missing("blog post", id)) if dep(:post_queries, server_context).by_id(id).nil?

          unnumbered = edits.map { it.except(:part) }

          case dep(:replace_post_edits, server_context).call(id, edits: unnumbered)
            in Failure(:published) then refuse(format(PUBLISHED, id))
            in result then stored(result, POST)
          end
        end

        def for_social_post(id, edits, server_context)
          social_post = dep(:social_post_queries, server_context).editable(id)
          return refuse(API::Wording.missing("unsent social post", id)) if social_post.nil?

          numbered = edits.map { it.merge(part: it.fetch(:part, FIRST_PART)) }
          missing = missing_part(numbered, social_post.parts.length)
          return refuse("social post #{id} has no part #{missing}") if missing

          stored(dep(:replace_social_post_edits, server_context).call(id, edits: numbered), SOCIAL_POST)
        end

        def missing_part(edits, count) = edits.map { it.fetch(:part) }.grep_v(FIRST_PART..count).first

        def stored(result, target)
          case result
            in Success(suggestion)
              answer(suggestion_id: suggestion.id, target:, edits: suggestion.edits.length, status: Blog::Types::SuggestionEditStatus["pending"])
            in Failure[:invalid, errors] then refuse(complaint(errors))
            else refuse(UNSTORED)
          end
        end
      end
    end
  end
end
