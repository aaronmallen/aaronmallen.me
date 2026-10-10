# frozen_string_literal: true

module Posts
  module Repos
    class PostLinkCheckMutations < Blog::DB::Repo
      root :post_link_checks

      def forget_unlinked(post_id, urls) = post_link_checks.unlinked(post_id, urls).delete

      def forget_unpublished = post_link_checks.outside(posts.published.select(:id).dataset.unordered).delete

      def record(**) = post_link_checks.record(**)
    end
  end
end
