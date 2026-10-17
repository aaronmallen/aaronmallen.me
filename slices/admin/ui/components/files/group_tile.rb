# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class GroupTile < Component
          GROUP_ICON = "fa-regular fa-folder-open"

          prop :group, Blog::Types::Instance(ROM::Struct)

          def view_template
            article(class: "file-card") do
              thumb
              div(class: "file-card-body") do
                p(class: "file-card-name", title: name) { opener }
                p(class: "file-card-link", title: link) { bare_url(link) }
                p(class: "file-card-meta") { meta }
                div(class: "file-card-acts") { acts }
              end
            end
          end

          private

          def acts
            copied = t(".copied")

            CopyButton(value: link, copied:, small: true, icon: "fa-solid fa-link") { t(".copy") }
            Button(
              href: link, small: true, variant: :gh, icon: :outbound,
              label: t(".open", name:), target: "_blank", rel: "noopener",
            )
          end

          def files = @group.share_group_files

          def image = files.find { Shares::ContentType.image?(it.content_type) }

          def link = Helpers::ShareLink.for(@group.code)

          def meta
            span { Blog::Helpers::Figures.size(files.sum(&:byte_size)) }
            span { l(Blog::TimeZone.today(@group.created_at), format: :medium) }
            span { t(".views", count: @group.view_count, views: Blog::Helpers::Figures.count(@group.view_count)) }
          end

          def name = @group.name || t(".name", count: files.size)

          def opener
            a(href: path(:admin_edit_file_group, id: @group.id),
              **Dialog.opens(ShareDrawer.id_for(GroupForm, @group))) do
              name
            end
          end

          def thumb
            if image
              img(class: "file-card-thumb", src: "#{link}/#{image.id}?preview", alt: image.alt_text.to_s,
                  loading: "lazy")
            else
              span(class: "file-card-thumb", aria: { hidden: true }) { Icon(GROUP_ICON) }
            end
          end
        end
      end
    end
  end
end
