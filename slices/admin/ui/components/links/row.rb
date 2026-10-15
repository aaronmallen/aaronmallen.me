# frozen_string_literal: true

require "uri"

module Admin
  module UI
    module Components
      module Links
        class Row < Component
          SCHEME = %r{\Ahttps?://(www\.)?}

          prop :link, Blog::Types::Instance(ROM::Struct)

          def self.host(destination) = URI.parse(destination).host.to_s.delete_prefix("www.")

          def view_template
            div(class: "link-row", data: { menu: path(:admin_link_menu, id: @link.id) }) do
              div(class: "link-row-main") do
                p(class: "link-row-title") { opener }
                p(class: "link-row-url", title: @link.destination) { @link.destination.sub(SCHEME, "") }
                p(class: "link-row-meta") { meta }
              end
              div(class: "link-row-acts") { acts }
            end
          end

          private

          def acts
            button(
              type: "button", class: "link-chip", title: t(".copy", link: short),
              data: { record_key: short, record_key_copied: t(".copied") },
            ) do
              plain Helpers::ShareLink.bare(short)
              Icon(:copy)
            end
            Button(
              href: @link.destination, small: true, variant: :gh, icon: :outbound,
              label: t(".open", link: @link.destination), target: "_blank", rel: "noopener",
            )
          end

          def date(time) = l(Blog::TimeZone.today(time), format: :medium)

          def host = self.class.host(@link.destination)

          def meta
            span { t(".clicks", count: @link.click_count, clicks: Blog::Helpers::Figures.count(@link.click_count)) }
            span { t(".made", on: date(@link.created_at)) }
            span { t(".retargeted", on: date(@link.retargeted_at)) } if @link.retargeted_at
          end

          def opener
            a(href: path(:admin_edit_link, id: @link.id), data: { dialog_open: ShareDrawer.id_for(LinkForm, @link) }) do
              @link.title || host
            end
          end

          def short = Helpers::ShareLink.for(@link.code)
        end
      end
    end
  end
end
