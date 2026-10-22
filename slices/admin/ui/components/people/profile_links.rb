# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class ProfileLinks < Component
          BLUESKY_PROFILE = "https://bsky.app/profile/%<did>s"
          MASTODON_PROFILE = "https://%<instance>s/@%<user>s"

          prop :person, Blog::Types::Instance(ROM::Struct)
          prop :networks, Blog::Types::Array.of(Blog::Types::NetworkName), default: -> { %w[mastodon bluesky] }

          def view_template
            mastodon if @person.mastodon_handle && @networks.include?("mastodon")
            bluesky if @person.bluesky_did && @networks.include?("bluesky")
          end

          private

          def bluesky
            link(
              format(BLUESKY_PROFILE, did: @person.bluesky_did), "bluesky",
              t(".bluesky_handle", handle: @person.bluesky_handle),
            )
          end

          def link(href, network, handle)
            a(class: ["person-link", network], href:, **OUTBOUND) do
              IconLabel(icon: Blog::Constants::NETWORK_ICONS.fetch(network)) { handle }
            end
          end

          def mastodon
            user, instance = @person.mastodon_handle.delete_prefix("@").split("@", 2)

            link(format(MASTODON_PROFILE, instance:, user:), "mastodon", @person.mastodon_handle)
          end
        end
      end
    end
  end
end
