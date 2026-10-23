# frozen_string_literal: true

module Posts
  module Repos
    class PostMutations < Blog::DB::Repo
      module Rendered
        def create(attributes) = super(Helpers::Rendering.with_body(attributes))

        def update(id, attributes = {}, **fields) = super(id, Helpers::Rendering.with_body(attributes.merge(fields)))
      end

      prepend Rendered

      root :posts

      stamped_commands :create, :update
      tagged_by :post_tags
      commands delete: :by_pk

      def hold_follow_up(**) = held_post_follow_ups.hold(**)

      def publish(id, at:) = posts.by_pk(id).unpublished.publish(at).first

      def publish_due(id, at:) = posts.by_pk(id).due_at(at).publish(at).first

      def record_webmentions(id, targets:, unsent:)
        posts.by_pk(id).command(:update).call(webmention_targets: targets, unsent_webmention_targets: unsent)
      end

      def release_follow_up(id) = held_post_follow_ups.by_pk(id).delete

      def replace_project_tags(id, names) = post_tags.retag_projects(id, names, tags)

      def rerender
        rerender_rows(posts, :body, Helpers::Rendering::BODY) { Helpers::Rendering.body(it) } +
          rerender_rows(post_edits, :note, Helpers::Rendering::NOTE) { Helpers::Rendering.note(it) }
      end

      private

      def rerender_rows(relation, source, columns)
        relation.select(:id, source, *columns).to_a.count do |row|
          fresh = yield row[source]
          next false if fresh == row.to_h.slice(*columns)

          relation.by_pk(row.id).where(source => row[source]).update(fresh).positive?
        end
      end
    end
  end
end
