# frozen_string_literal: true

module Posts
  module Repos
    class PostEditRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def edited_at(post_ids) = post_edits.edited_at(post_ids).to_a.to_h { [it.post_id, it.edited_at] }

      def for_post(post_id) = post_edits.for_post(post_id).oldest_first.to_a

      def for_posts(post_ids) = post_edits.for_posts(post_ids).oldest_first.to_a.group_by(&:post_id)

      def on_post?(post_id, id) = post_edits.for_post(post_id).by_pk(id).exist?
    end
  end
end
