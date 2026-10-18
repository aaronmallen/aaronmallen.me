# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Part < Component
          COUNT = /%\{count\}/
          MAX = /%\{max\}/

          prop :body, Blog::Types::String
          prop :counts, Blog::Types::Hash
          prop :networks, Blog::Types::Array.of(Blog::Types::Instance(Structs::Network))
          prop :photos, Blog::Types::Array.of(Blog::Types::Hash), default: Blog::Constants::EMPTY_ARRAY
          prop :removable, Blog::Types::Bool, default: false
          prop :autofocus, Blog::Types::Bool, default: false

          include Deps[media_store: "media_store.client"]

          def view_template
            div(class: "compose-part", data: { social_part: "" }) do
              div(class: "compose-part-head", data: { label: t(".label") }) { remove_button }
              Textarea(value: @body, **body_attributes)
              photos
              Counts(counts: @counts, networks: @networks)
              preview
            end
          end

          private

          def body_attributes
            {
              class: "compose-body",
              name: "social[parts][]",
              placeholder: t(".placeholder"),
              aria: { label: t(".body") },
              autofocus: @autofocus,
              data: { social_body: "" },
            }
          end

          def photo_bar
            div(class: "compose-photo-bar") do
              Button(variant: :gh, small: true, icon: "fa-regular fa-image", data: { social_photo_pick: "" }) do
                t(".add_photo")
              end
              input(type: "file", accept: "image/*", multiple: true, hidden: true, data: { social_photo_file: "" })
              photo_count
              p(class: "edit-alert", role: "alert", data: { social_photo_alert: "" })
              template(data: { social_photo_template: "" }) { Photo() }
            end
          end

          def photo_count
            template = t(".photo_count").sub(MAX, ::Social::Contracts::SocialPostContract::MAX_PHOTOS.to_s)

            span(class: "compose-photo-count", data: { social_photo_count: "", template: }) do
              template.sub(COUNT, @photos.size.to_s)
            end
          end

          def photos
            div(class: "compose-photos", data: photos_data) do
              input(type: "hidden", name: Photo::FIELD, value: "")
              ol(class: "compose-photo-list", aria: { label: t(".photos") }, data: { social_photo_list: "" }) do
                @photos.each { Photo(**it) }
              end
              photo_bar if uploads?
            end
          end

          def photos_data
            return { social_photos: "" } unless uploads?

            { social_photos: "", social_upload: path(:admin_create_photo), social_upload_failed: t(".upload_failed"),
              social_photos_full: t(".photos_full") }
          end

          def preview
            div(class: "compose-preview", hidden: !previewing?, data: { social_preview: "" }) do
              p(class: "compose-preview-head") { t(".preview") }
              @networks.each { preview_line(it) }
              preview_photos
            end
          end

          def preview_line(network)
            p(class: "compose-preview-line", hidden: !network.selected, data: { social_preview_line: network.name }) do
              span(class: "compose-preview-network") { network.label }
              span(class: "compose-preview-text", data: { social_preview_text: "" }) { preview_text(network) }
            end
          end

          def preview_photo(photo)
            img(class: "compose-preview-photo", src: Blog::Helpers::MediaPath.for(photo[:key]), alt: photo[:alt])
          end

          def preview_photos
            div(class: "compose-preview-photos", data: { social_preview_photos: "" }) do
              @photos.each { preview_photo(it) }
            end
          end

          def preview_text(network) = @counts.fetch(network.name, ::Social::Structs::NetworkCount::NONE).text

          def previewing?
            (@photos.any? || @body.match?(::Social::Operations::ResolveMentions::TOKEN)) && @networks.any?(&:selected)
          end

          def remove_button
            Button(variant: :gh, small: true, hidden: !@removable, data: { social_remove: "" }) { t(".remove") }
          end

          def uploads? = media_store.configured?
        end
      end
    end
  end
end
