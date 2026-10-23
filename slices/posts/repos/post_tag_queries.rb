# frozen_string_literal: true

module Posts
  module Repos
    class PostTagQueries < Blog::DB::Repo
      def page_by_tag(tag_ids, page) = page.fill(posts.lean.carrying(:post_tags, tag_ids).newest_first.paged(page).to_a)
    end
  end
end
