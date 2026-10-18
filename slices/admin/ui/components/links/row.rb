# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Links
        class Row < Component
          prop :link, Blog::Types::Instance(ROM::Struct)
          prop :check, Blog::Types::Instance(ROM::Struct).optional, default: nil

          def view_template
            div(class: "link-row", data: { menu: path(:admin_link_menu, id: @link.id) }) do
              div(class: "link-row-main") do
                p(class: "link-row-title") { opener }
                p(class: "link-row-url", title: @link.destination) { bare_url(@link.destination) }
                p(class: "link-row-meta") { meta }
              end
              div(class: "link-row-acts") { acts }
            end
          end

          private

          def acts
            CopyButton(
              value: short, copied: t(".copied"), bare: true, class: "link-chip", title: t(".copy", link: short),
            ) do
              plain bare_url(short)
              Icon(:copy)
            end
            Button(
              href: @link.destination, small: true, variant: :gh, icon: :outbound,
              label: t(".open", link: @link.destination), target: "_blank", rel: "noopener",
            )
          end

          def date(time) = l(Blog::TimeZone.local_date(time), format: :medium)

          def host = self.class.host(@link.destination)

          def meta
            LinkCheckPill(check: @check)
            span(class: "link-row-reason") { @check.reason } if @check&.reason
            span { t(".clicks", count: @link.click_count, clicks: Blog::Helpers::Figures.count(@link.click_count)) }
            span { t(".made", on: date(@link.created_at)) }
            span { t(".retargeted", on: date(@link.retargeted_at)) } if @link.retargeted_at
          end

          def opener
            a(href: path(:admin_edit_link, id: @link.id), **Dialog.opens(ShareDrawer.id_for(LinkForm, @link))) do
              Helpers::ShareLink.link_name(@link)
            end
          end

          def short = Helpers::ShareLink.for(@link.code)
        end
      end
    end
  end
end
