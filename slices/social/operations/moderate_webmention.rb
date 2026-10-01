# frozen_string_literal: true

module Social
  module Operations
    class ModerateWebmention < Blog::Operation
      APPROVED = Blog::Types::WebmentionStatus["approved"]
      IGNORED = Blog::Types::WebmentionStatus["ignored"]

      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(id, verdict)
        step found(moderated(id, Blog::Types::WebmentionStatus[verdict]))
      end

      private

      def found(mention) = mention ? Success(mention) : Failure(:not_found)

      def moderated(id, verdict)
        case verdict
        when APPROVED then webmention_repo.approve(id)
        when IGNORED then webmention_repo.ignore(id)
        else webmention_repo.mark_spam(id)
        end
      end
    end
  end
end
