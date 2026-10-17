# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class TrustedAuthorsCard < Component
          prop :authors, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            note = t(".count", count: @authors.size)

            Card(title: t(".title"), note:, note_class: "settings-count", id: "trusted-authors") do
              Hint { t(".hint") }
              @authors.empty? ? Empty { t(".empty") } : @authors.each { row(it) }
            end
          end

          private

          def remove_form(url)
            ButtonForm(
              action: path(:admin_remove_trusted_author), label: t(".remove"), variant: :warn,
              confirm: t(".confirm", author: url), hidden: { author_url: url },
            )
          end

          def row(author) = ListItem(title: author.author_url) { remove_form(author.author_url) }
        end
      end
    end
  end
end
