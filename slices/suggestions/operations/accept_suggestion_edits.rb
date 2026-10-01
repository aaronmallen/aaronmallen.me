# frozen_string_literal: true

module Suggestions
  module Operations
    class AcceptSuggestionEdits < Blog::Operation
      PUBLISHED = Blog::Types::PostStatus["published"]

      include Deps[
        lock_editable_social_post: "social.operations.lock_editable_social_post",
        lock_post: "posts.operations.lock_post",
        mention_directory: "social.queries.mention_directory",
        networks: "social.networks.all",
        replace_social_post_parts: "social.operations.replace_social_post_parts",
        revise_post_body: "posts.operations.revise_post_body",
        suggestion_repo: "repos.suggestion_repo",
      ]

      def call(suggestion_id, ids: nil)
        suggestion = step find(suggestion_id)
        edits = step chosen(suggestion, ids)

        transaction { accept(suggestion, edits) }
      end

      private

      def accept(suggestion, edits)
        return accept_on_post(suggestion.post_id, edits) if suggestion.post_id

        accept_on_social_post(suggestion.social_post_id, edits)
      end

      def accept_on_post(post_id, edits)
        post = step unpublished(lock_post.call(post_id))
        bodies, sifted = sift([post.body], still_pending(edits), Blog::Constants::EMPTY_ARRAY)
        revise_post_body.call(post.id, body: bodies.first) if sifted.fetch(:accepted).any?

        outcome(sifted)
      end

      def accept_on_social_post(social_post_id, edits)
        social_post = step editable(lock_editable_social_post.call(social_post_id))
        bodies, sifted = sift(social_post.parts.map(&:body), still_pending(edits), social_post.targets.to_a)
        step replaced(social_post.id, bodies) if sifted.fetch(:accepted).any?

        outcome(sifted)
      end

      def apply_edit(bodies, edit, targets)
        index = edit.part_number - 1
        body = bodies[index]
        return :stale unless body && edit.applies_to?(body)

        replaced = edit.apply_to(body)
        return :refused unless fits?(replaced, targets)

        bodies[index] = replaced
        :accepted
      end

      def chosen(suggestion, ids)
        open = suggestion.open_edits
        open = open.select { Array(ids).include?(it.id) } if ids
        pending = open.select(&:pending?)
        return Success(pending) if pending.any?

        open.any? ? Failure(:stale) : Failure(:not_found)
      end

      def editable(record) = record ? Success(record) : Failure(:already_posted)

      def find(id)
        suggestion = suggestion_repo.by_id(id)
        suggestion ? Success(suggestion) : Failure(:not_found)
      end

      def fits?(body, targets)
        return true if targets.empty?

        directory = mention_directory.call([body])

        targets.all? { networks.fetch(it).within_limit?(directory.expand(body, it).text) }
      end

      def outcome(sifted)
        {
          accepted: suggestion_repo.accept(sifted.fetch(:accepted).map(&:id)),
          refused: sifted.fetch(:refused),
          stale: suggestion_repo.mark_stale(sifted.fetch(:stale).map(&:id)),
        }
      end

      def replaced(id, bodies) = editable(replace_social_post_parts.call(id, bodies))

      def sift(bodies, edits, targets)
        sifted = { accepted: [], refused: [], stale: [] }
        edits.each { sifted.fetch(apply_edit(bodies, it, targets)) << it }

        [bodies, sifted]
      end

      def still_pending(edits) = suggestion_repo.lock_pending(edits.map(&:id))

      def unpublished(post)
        return Failure(:not_found) unless post
        return Failure(:published) if post.status == PUBLISHED

        Success(post)
      end
    end
  end
end
