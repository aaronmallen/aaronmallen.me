# frozen_string_literal: true

module Public
  module UI
    module Components
      class ProfileLinks < Component
        PROFILES = {
          github: [Blog::Constants::GITHUB_ICON, ".github"].freeze,
          bluesky: [Blog::Constants::NETWORK_ICONS.fetch("bluesky"), ".bluesky"].freeze,
          linkedin: [Blog::Constants::NETWORK_ICONS.fetch("linkedin"), ".linkedin"].freeze,
          mastodon: [Blog::Constants::NETWORK_ICONS.fetch("mastodon"), ".mastodon"].freeze,
        }.freeze

        prop :networks, Blog::Types::Array.of(Blog::Types::Symbol)
        prop :link, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
        prop :listed, Blog::Types::Bool, default: true

        include Deps["settings"]

        def view_template
          Profiles.call(settings, *@networks).each do |network, href|
            @listed ? li { profile(network, href) } : profile(network, href)
          end
        end

        private

        def profile(network, href)
          icon, key = PROFILES.fetch(network)
          a(**@link, href:) { IconLabel(icon:) { t(key) } }
        end
      end
    end
  end
end
