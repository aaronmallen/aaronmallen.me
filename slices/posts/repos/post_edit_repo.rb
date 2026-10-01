# frozen_string_literal: true

module Posts
  module Repos
    class PostEditRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }

      def for_post(post_id) = post_edits.for_post(post_id).oldest_first.to_a
    end
  end
end
