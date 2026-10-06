# frozen_string_literal: true

module Posts
  module Operations
    class SavePost < Blog::Operation
      include Deps[
        claim_post_photos: "operations.claim_post_photos",
        contract: "contracts.post_contract",
        post_edit_repo: "repos.post_edit_repo",
        post_repo: "repos.post_repo",
        publish_post: "operations.publish_post",
        queue_follow_up: "operations.queue_follow_up",
      ]

      CARD = %i[syndication_body syndication_enabled syndication_targets webmentions_enabled].freeze
      DRAFT = Blog::Types::PostIntent["draft"]
      FIELDS = %i[title slug summary tags body publish_at og_title og_image_url canonical_url].freeze
      NOTE = :edit_note
      PUBLISH = Blog::Types::PostIntent["publish"]
      SLUG_CONSTRAINTS = { "posts_published_slug_locked" => "locked", "posts_slug_key" => "taken" }.freeze

      def call(params, id: nil, intent: DRAFT, now: Time.now)
        attributes = step validate(params, intent)
        step persist(id, attributes, intent, now)
      end

      private

      def create_or_update(post, attributes)
        fields = attributes.except(:tags, NOTE)
        saved = post ? post_repo.update(post.id, fields) : post_repo.create(fields)
        post_repo.replace_tags(saved.id, attributes.fetch(:tags))
        claim_post_photos.call(saved)

        post_repo.by_id(saved.id)
      end

      def draft(post, attributes)
        Success([:drafted, create_or_update(post, attributes.merge(status: Blog::Types::PostStatus["draft"]))])
      end

      def edited?(post, attributes) = lines(post.body) != lines(attributes[:body])

      def find(id)
        return Success(nil) unless id

        found(post_repo.by_id_for_update(id))
      end

      def form(params)
        given = FIELDS.to_h { [it, params[it]] }.merge(params.slice(*CARD, NOTE))

        given.merge(slug: PostSlug.derive(slug: given[:slug], title: given[:title]))
      end

      def invalid(field, code) = Failure([:invalid, { field => [code] }])

      def kept(post, attributes)
        saved = post&.published_at
        given = attributes[:published_at]
        same = saved && given && Blog::TimeZone.input_value(saved) == Blog::TimeZone.input_value(given)

        same ? attributes.merge(published_at: saved) : attributes
      end

      def lines(text) = text.encode(universal_newline: true)

      def persist(id, attributes, intent, now)
        transaction do
          post = step find(id)
          save(post, kept(post, attributes), intent, now)
        end
      rescue ROM::SQL::UniqueConstraintError, ROM::SQL::CheckConstraintError => e
        code = SLUG_CONSTRAINTS[post_repo.violated_constraint(e)]
        raise unless code

        invalid(:slug, code)
      end

      def publish_now(post, attributes, now)
        saved = create_or_update(post, attributes.merge(status: Blog::Types::PostStatus["draft"]))
        Success([:published, step(publish_post.call(saved.id, at: now))])
      end

      def resending(attributes) = attributes.except(:published_at).merge(unsent_webmention_targets: [])

      def save(post, attributes, intent, now)
        return update_published(post, attributes) if post&.status == Blog::Types::PostStatus["published"]
        return draft(post, attributes) unless intent == PUBLISH
        return schedule(post, attributes) if attributes[:published_at]&.>(now)

        publish_now(post, attributes, now)
      end

      def schedule(post, attributes)
        Success([:scheduled, create_or_update(post, attributes.merge(status: Blog::Types::PostStatus["scheduled"]))])
      end

      def update_published(post, attributes)
        edited = edited?(post, attributes)
        note = attributes[NOTE].to_s
        return invalid(NOTE, Blog::Contract::BLANK) if edited && note.empty?

        post_edit_repo.create(post_id: post.id, note:) if edited
        saved = create_or_update(post, resending(attributes))
        post_repo.after_commit { queue_follow_up.call(saved.id, QueueFollowUp::SEND_WEBMENTIONS) }

        Success([:saved, saved])
      end

      def validate(params, intent)
        attributes = step validated(contract.call(form(params), intent:))
        publish_at = attributes.delete(:publish_at)
        Success(attributes.merge(published_at: publish_at))
      end
    end
  end
end
