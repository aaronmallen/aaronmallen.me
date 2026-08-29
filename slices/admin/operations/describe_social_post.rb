# frozen_string_literal: true

module Admin
  module Operations
    class DescribeSocialPost
      include Deps["i18n"]

      def call(social_post)
        posted_at = social_post.posted_at

        {
          date: posted_at && i18n.l(Blog::TimeZone.today(posted_at), format: :medium),
          networks: networks(social_post),
          time: posted_at && i18n.l(Blog::TimeZone.local(posted_at), format: :clock),
        }
      end

      private

      def networks(social_post)
        social_post.targets.map { i18n.t(Structs::Network::LABELS.fetch(it)) }.join(Structs::Network::SEPARATOR)
      end
    end
  end
end
