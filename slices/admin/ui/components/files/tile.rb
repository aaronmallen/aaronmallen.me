# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class Tile < Component
          ICONS = {
            %r{\Aapplication/pdf\z} => "fa-regular fa-file-pdf",
            /zip|gzip|tar/ => "fa-regular fa-file-zipper",
            %r{\Avideo/} => "fa-regular fa-file-video",
            %r{\Aaudio/} => "fa-regular fa-file-audio",
            %r{\Atext/|json|javascript} => "fa-regular fa-file-code",
          }.freeze
          FILE_ICON = "fa-regular fa-file"
          IMAGE = %r{\Aimage/}

          prop :share, Blog::Types::Instance(ROM::Struct)

          def view_template
            article(class: "file-card", data: { menu: path(:admin_file_menu, id: @share.id) }) do
              thumb
              div(class: "file-card-body") do
                p(class: "file-card-name", title: @share.filename) { opener }
                p(class: "file-card-link", title: link) { Helpers::ShareLink.bare(link) }
                p(class: "file-card-meta") { meta }
                div(class: "file-card-acts") { acts }
              end
            end
          end

          private

          def acts
            copied = t(".copied")

            Button(small: true, icon: "fa-solid fa-link", data: { record_key: link, record_key_copied: copied }) do
              t(".copy")
            end
            Button(
              href: link, small: true, variant: :gh, icon: "fa-solid fa-arrow-up-right-from-square",
              label: t(".open", name: @share.filename), target: "_blank", rel: "noopener",
            )
          end

          def downloads = Blog::Helpers::Figures.count(@share.download_count)

          def icon = ICONS.find { |type, _| type.match?(@share.content_type) }&.last || FILE_ICON

          def image? = IMAGE.match?(@share.content_type)

          def link = Helpers::ShareLink.for(@share.code)

          def meta
            span { Blog::Helpers::Figures.size(@share.byte_size) }
            span { l(Blog::TimeZone.today(@share.created_at), format: :medium) }
            span { t(".downloads", count: @share.download_count, downloads: downloads) }
          end

          def opener
            a(
              href: path(:admin_edit_file, id: @share.id),
              data: { dialog_open: ShareDrawer.id_for(ShareForm, @share) },
            ) { @share.filename }
          end

          def preview = Helpers::ShareLink.preview(@share.code)

          def thumb
            return img(class: "file-card-thumb", src: preview, alt: @share.alt_text.to_s, loading: "lazy") if image?

            span(class: "file-card-thumb", aria: { hidden: true }) { Icon(icon) }
          end
        end
      end
    end
  end
end
