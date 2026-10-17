# frozen_string_literal: true

module Posts
  module Repos
    class PostTagQueries < Blog::DB::Repo
      def page_by_tag(tag, page) = page.fill(posts.lean.tagged(tag).newest_first.paged(page).to_a)
    end
  end
end
