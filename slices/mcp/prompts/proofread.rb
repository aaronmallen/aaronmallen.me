# frozen_string_literal: true

module MCP
  module Prompts
    class Proofread < Prompt
      NUMBER = /\A\d+\z/
      POST = "post"
      SOCIAL_POST = "social_post"
      TARGETS = [POST, SOCIAL_POST].freeze
      USER = "user"
      WRAP = /(?<!\n)\n(?!\n)/

      RULES = <<~RULES
        Fix grammar, spelling and punctuation, and nothing else. Leave the style, the tone, the word choice and
        the structure as they stand. Do not tighten a sentence, swap a word for one you like better, or move
        anything around. A turn of phrase you would not have written is not a mistake.

        Skip code blocks, inline code and link targets. Leave markdown syntax alone, headings, list markers,
        emphasis and link brackets included. Proofread the words they wrap.

        Give each fix the original text copied from the body exactly as it stands, the replacement, and a reason
        of a few words, such as "typo" or "subject-verb agreement". Keep each fix small, and take in enough words
        around the mistake that the original appears once in the body.

        Call suggest_edits once, with every fix in it, since a new call replaces the fixes still waiting. It
        changes nothing on its own: each fix waits for the author to accept or reject it. When you find no
        mistakes, say so and call nothing.
      RULES

      prompt_name "proofread"
      title "Proofread a post"
      description "Read one blog post or unsent social post, fix only its grammar, spelling and punctuation, " \
                  "and send each fix through suggest_edits for the author to accept or reject"
      arguments [
        Prompt::Argument.new(name: "target", description: "#{POST} or #{SOCIAL_POST}", required: true),
        Prompt::Argument.new(name: "id", description: "the ID of the post or social post to proofread", required: true),
      ]

      class << self
        def template(args)
          target = args[:target].to_s
          id = args[:id].to_s
          refuse("target takes #{POST} or #{SOCIAL_POST}") unless TARGETS.include?(target)
          refuse("id takes a number") unless NUMBER.match?(id)

          Prompt::Result.new(description: headline(target, id), messages: [say(instructions(target, id))])
        end

        private

        def headline(target, id) = "Proofread #{target == POST ? 'blog post' : 'social post'} #{id}"

        def instructions(target, id)
          ["#{headline(target, id)}.", steps(target, id), RULES].map { unwrap(it) }.join("\n\n")
        end

        def post_steps(id)
          <<~TEXT
            Call read_post with the ID #{id} and read its markdown body. Then send every fix in one call to
            suggest_edits, with the target "#{POST}" and the ID #{id}.
          TEXT
        end

        def refuse(message)
          raise Server::RequestHandlerError.new(
            message,
            nil,
            error_type: :invalid_arguments,
            error_code: JsonRpcHandler::ErrorCode::INVALID_PARAMS,
          )
        end

        def say(text) = Prompt::Message.new(role: USER, content: Content::Text.new(text))

        def social_post_steps(id)
          <<~TEXT
            Call read_social_post with the ID #{id} and read its parts in order. Then send every fix in one call
            to suggest_edits, with the target "#{SOCIAL_POST}" and the ID #{id}. Give each fix the number of the
            part it belongs to, counting from 1.
          TEXT
        end

        def steps(target, id) = target == POST ? post_steps(id) : social_post_steps(id)

        def unwrap(text) = text.strip.gsub(WRAP, " ")
      end
    end
  end
end
