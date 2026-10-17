# frozen_string_literal: true

module Posts
  module Operations
    class SavePost < Blog::Operation
      include Deps[
        claim_post_photos: "operations.claim_post_photos",
        contract: "contracts.post_contract",
        post_edit_mutations: "repos.post_edit_mutations",
        post_mutations: "repos.post_mutations",
        post_queries: "repos.post_queries",
        publish_post: "operations.publish_post",
        queue_follow_up: "operations.queue_follow_up",
        social_post_queries: "social.repos.social_post_queries",
      ]

      CARD = %i[syndication_body syndication_enabled syndication_targets webmentions_enabled].freeze
      DRAFT = Blog::Types::PostIntent["draft"]
      FIELDS = %i[title slug summary tags body publish_at og_title og_image_url canonical_url].freeze
      NOTE = :edit_note
      PUBLISH = Blog::Types::PostIntent["publish"]
      SLUG_CONSTRAINTS = {
        "posts_published_slug_locked" => [:slug, "locked"],
        "posts_slug_key" => [:slug, "taken"],
      }.freeze

      def call(params, id: nil, intent: DRAFT, now: Time.now)
        attributes = step validate(params, announcing: announcing?(id, intent))
        step persist(id, attributes, intent, now)
      end

      private

      def announcing?(id, intent)
        return true if intent == PUBLISH

        post = post_queries.by_id(id) if id
        post&.published? && unannounced?(post)
      end

      def create_or_update(post, attributes)
        fields = attributes.except(:tags, NOTE)
        saved = post ? post_mutations.update(post.id, fields) : post_mutations.create(fields)
        post_mutations.replace_tags(saved.id, attributes.fetch(:tags))
        claim_post_photos.call(saved)

        post_queries.by_id(saved.id)
      end

      def draft(post, attributes)
        Success([:drafted, create_or_update(post, attributes.merge(status: Blog::Types::PostStatus["draft"]))])
      end

      def edited?(post, attributes) = lines(post.body) != lines(attributes[:body])

      def find(id)
        return Success(nil) unless id

        found(post_mutations.by_id_for_update(id))
      end

      def follow_up(post)
        post_mutations.after_commit { queue_follow_up.call(post.id, QueueFollowUp::SEND_WEBMENTIONS) }
        return unless post.syndication_enabled && unannounced?(post)

        post_mutations.after_commit { queue_follow_up.call(post.id, QueueFollowUp::SYNDICATE_POST) }
      end

      def form(params)
        given = FIELDS.to_h { [it, params[it]] }.merge(params.slice(*CARD, NOTE))

        given.merge(slug: Helpers::PostSlug.derive(slug: given[:slug], title: given[:title]))
      end

      def kept(post, attributes)
        saved = post&.published_at
        given = attributes[:published_at]
        same = saved && given && Blog::TimeZone.input_value(saved) == Blog::TimeZone.input_value(given)

        same ? attributes.merge(published_at: saved) : attributes
      end

      def lines(text) = text.encode(universal_newline: true)

      def persist(id, attributes, intent, now)
        constrained(post_mutations, SLUG_CONSTRAINTS) do
          transaction do
            post = step find(id)
            save(post, kept(post, attributes), intent, now)
          end
        end
      end

      def publish_now(post, attributes, now)
        saved = create_or_update(post, attributes.merge(status: Blog::Types::PostStatus["draft"]))
        Success([:published, step(publish_post.call(saved.id, at: now))])
      end

      def resending(attributes) = attributes.except(:published_at).merge(unsent_webmention_targets: [])

      def save(post, attributes, intent, now)
        return update_published(post, attributes) if post&.published?
        return draft(post, attributes) unless intent == PUBLISH
        return schedule(post, attributes) if attributes[:published_at]&.>(now)

        publish_now(post, attributes, now)
      end

      def schedule(post, attributes)
        Success([:scheduled, create_or_update(post, attributes.merge(status: Blog::Types::PostStatus["scheduled"]))])
      end

      def unannounced?(post) = !social_post_queries.any_for_post?(post.id)

      def update_published(post, attributes)
        edited = edited?(post, attributes)
        note = attributes[NOTE].to_s
        return invalid(NOTE, Blog::Contract::BLANK) if edited && note.empty?

        post_edit_mutations.create(post_id: post.id, note:) if edited
        saved = create_or_update(post, resending(attributes))
        follow_up(saved)

        Success([:saved, saved])
      end

      def validate(params, announcing:)
        attributes = step validated(contract.call(form(params), announcing:))
        publish_at = attributes.delete(:publish_at)
        Success(attributes.merge(published_at: publish_at))
      end
    end
  end
end
