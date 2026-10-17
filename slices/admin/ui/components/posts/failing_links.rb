# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class FailingLinks < Component
          FORM = "broken-links-check"

          prop :post_id, Blog::Types::Integer
          prop :links, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            div(class: "post-broken-links") do
              @links.each do |link|
                LinkCheckRow(**link, published: true, form: FORM, action:) { fix_button(link[:url]) }
              end
            end
          end

          private

          def action = path(:admin_check_post_links, id: @post_id)

          def fix_button(url)
            Button(
              href: path(:admin_edit_post, id: @post_id, links: Blog::Constants::CHECKED), small: true, variant: :gh,
              icon: :edit, label: t(".fix", link: url),
            )
          end
        end
      end
    end
  end
end
