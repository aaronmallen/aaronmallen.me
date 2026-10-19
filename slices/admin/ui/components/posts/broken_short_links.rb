# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class BrokenShortLinks < Component
          prop :links, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :total, Blog::Types::Integer

          def view_template
            Card(title: t(".title"), class: "post-broken-short") do |card|
              card.side do
                span { t(".failing", count: @links.size, total: @total) }
                a(href: path(:admin_links)) { t(".all") }
              end
              @links.each { row(it) }
            end
          end

          private

          def change_button(link)
            Button(
              href: path(:admin_edit_link, id: link.id), small: true, variant: :gh,
              icon: :edit, label: t(".change", link: link.destination),
            )
          end

          def row(link)
            LinkCheckRow(
              url: link.destination, text: Helpers::ShareLink.bare_for(link.short), check: link,
              published: true, form: FailingLinks::FORM, action: path(:admin_check_link, id: link.id),
            ) { change_button(link) }
          end
        end
      end
    end
  end
end
