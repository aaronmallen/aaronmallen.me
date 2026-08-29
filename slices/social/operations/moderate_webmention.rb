# frozen_string_literal: true

module Social
  module Operations
    class ModerateWebmention < Blog::Operation
      APPROVED = Blog::Types::WebmentionStatus["approved"]

      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(id, verdict)
        step found(moderated(id, Blog::Types::WebmentionStatus[verdict]))
      end

      private

      def found(mention) = mention ? Success(mention) : Failure(:not_found)

      def moderated(id, verdict)
        verdict == APPROVED ? webmention_repo.approve(id) : webmention_repo.mark_spam(id)
      end
    end
  end
end
