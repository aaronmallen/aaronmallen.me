# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class ProfileLinks < Component
          BLUESKY_PROFILE = "https://bsky.app/profile/%<did>s"
          MASTODON_PROFILE = "https://%<instance>s/@%<user>s"

          prop :person, Blog::Types::Instance(ROM::Struct)

          def view_template
            span(class: "person-links") do
              bluesky if @person.bluesky_did
              mastodon if @person.mastodon_handle
            end
          end

          private

          def bluesky
            link(
              format(BLUESKY_PROFILE, did: @person.bluesky_did), "fa-bluesky", ".bluesky",
              t(".bluesky_handle", handle: @person.bluesky_handle),
            )
          end

          def link(href, icon, label_key, handle)
            a(
              class: "person-link", href:, target: "_blank", rel: "noopener noreferrer", title: handle,
              aria: { label: t(label_key, name: @person.name) },
            ) { Icon(["fa-brands", icon]) }
          end

          def mastodon
            user, instance = @person.mastodon_handle.delete_prefix("@").split("@", 2)

            link(format(MASTODON_PROFILE, instance:, user:), "fa-mastodon", ".mastodon", @person.mastodon_handle)
          end
        end
      end
    end
  end
end
