# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ShipsNextCard < Component
        QUEUE_FILTER = Blog::Types::SocialQueue["queued"]
        SEPARATOR = " · "

        prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :social_posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :summaries, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::String)

        def view_template
          Card(title: t(".title")) do
            next Empty { t(".empty") } if @posts.empty? && @social_posts.empty?

            @posts.each { post_row(it) }
            @social_posts.each { social_row(it) }
          end
        end

        private

        def post_row(post)
          ListItem(
            title: post.title,
            href: path(:admin_edit_post, id: post.id),
            sub: l(Blog::TimeZone.local(post.published_at), format: :medium),
          )
        end

        def social_row(social_post)
          ListItem(
            title: @summaries.fetch(social_post.id),
            href: path(:admin_social, filter: QUEUE_FILTER),
            sub: social_sub(social_post),
          )
        end

        def social_sub(social_post)
          networks = social_post.targets.map { t(Structs::Network::LABELS.fetch(it)) }.join(Structs::Network::SEPARATOR)

          [l(Blog::TimeZone.local(social_post.posted_at), format: :medium), networks].join(SEPARATOR)
        end
      end
    end
  end
end
