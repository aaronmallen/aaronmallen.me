# frozen_string_literal: true

require "time"

module Public
  module UI
    module StructuredData
      CONTEXT = "https://schema.org"

      module_function

      def owner = { "@type": "Person", "@id": owner_id, name: settings.owner_name, url: settings.site_url }

      def owner_id = settings.site_url("/#owner")

      def post(post, description:, path:)
        url = post.canonical_url || settings.site_url(path)
        tags = post.tags.map(&:name)

        {
          "@context": CONTEXT,
          "@type": "BlogPosting",
          headline: post.title,
          description:,
          datePublished: post.published_at.utc.iso8601,
          dateModified: post.updated_at.utc.iso8601,
          author: owner,
          image: post.og_image_url,
          url:,
          mainEntityOfPage: url,
          keywords: (tags unless tags.empty?),
        }.compact
      end

      def profiles = Profiles.call(:github, :bluesky, :mastodon).values

      def settings = Hanami.app.settings

      def site = { "@context": CONTEXT, "@graph": [website, owner.merge(sameAs: profiles)] }

      def website
        {
          "@type": "WebSite",
          "@id": settings.site_url("/#website"),
          url: settings.site_url,
          name: settings.owner_name,
          publisher: { "@id": owner_id },
        }
      end
    end
  end
end
