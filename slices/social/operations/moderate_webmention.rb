# frozen_string_literal: true

module Social
  module Operations
    class ModerateWebmention < Blog::Operation
      APPROVED = Blog::Types::WebmentionStatus["approved"]
      IGNORED = Blog::Types::WebmentionStatus["ignored"]
      SPAM = Blog::Types::WebmentionStatus["spam"]

      include Deps[
        webmention_mutations: "repos.webmention_mutations",
        webmention_queries: "repos.webmention_queries",
      ]

      def call(id, verdict, reason: nil)
        verdict = Blog::Types::WebmentionStatus[verdict]

        transaction do
          mention = step found(moderated(id, verdict, visible(reason)))
          retrust(mention, verdict) if mention.author_url
          mention
        end
      end

      private

      def moderated(id, verdict, reason)
        case verdict
          when APPROVED then webmention_mutations.approve(id)
          when IGNORED then webmention_mutations.ignore(id)
          else webmention_mutations.mark_spam(id, reason)
        end
      end

      def retrust(mention, verdict)
        case verdict
          when APPROVED then trust(mention) if Repos::WebmentionQueries::LISTED_TYPES.include?(mention.type)
          when SPAM then webmention_mutations.distrust(mention.author_url)
        end
      end

      def trust(mention)
        approve_pending = webmention_queries.settings.auto_approve_known_authors

        webmention_mutations.trust(mention.author_url, approve_pending:)
      end

      def visible(reason) = Blog::Types::OptionalText[reason]&.then { it if it.match?(Blog::Contract::VISIBLE) }
    end
  end
end
