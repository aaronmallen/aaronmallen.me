# frozen_string_literal: true

require "uri"

module Admin
  module UI
    module Components
      module Links
        class Row < Component
          SCHEME = %r{\Ahttps?://(www\.)?}

          prop :link, Blog::Types::Instance(ROM::Struct)

          def view_template
            div(class: "link-row") do
              div(class: "link-row-main") do
                p(class: "link-row-title") { @link.title || host }
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
              Icon("fa-regular fa-copy")
            end
            Button(
              href: @link.destination, small: true, variant: :gh, icon: "fa-solid fa-arrow-up-right-from-square",
              label: t(".open", link: @link.destination), target: "_blank", rel: "noopener",
            )
          end

          def date(time) = l(Blog::TimeZone.today(time), format: :medium)

          def host = URI.parse(@link.destination).host.to_s.delete_prefix("www.")

          def meta
            span { t(".clicks", count: @link.click_count, clicks: Blog::Helpers::Figures.count(@link.click_count)) }
            span { t(".made", on: date(@link.created_at)) }
            span { t(".retargeted", on: date(@link.retargeted_at)) } if @link.retargeted_at
          end

          def short = Helpers::ShareLink.for(@link.code)
        end
      end
    end
  end
end
