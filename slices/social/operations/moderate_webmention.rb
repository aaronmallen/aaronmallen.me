# frozen_string_literal: true

module Social
  module Operations
    class ModerateWebmention < Operation
      APPROVED = Blog::Types::WebmentionStatus["approved"]
      IGNORED = Blog::Types::WebmentionStatus["ignored"]

      include Deps[webmention_mutations: "repos.webmention_mutations"]

      def call(id, verdict, reason: nil)
        step found(moderated(id, Blog::Types::WebmentionStatus[verdict], visible(reason)))
      end

      private

      def moderated(id, verdict, reason)
        case verdict
        when APPROVED then webmention_mutations.approve(id)
        when IGNORED then webmention_mutations.ignore(id)
        else webmention_mutations.mark_spam(id, reason)
        end
      end

      def visible(reason) = Blog::Types::OptionalText[reason]&.then { it if it.match?(Blog::Contract::VISIBLE) }
    end
  end
end
