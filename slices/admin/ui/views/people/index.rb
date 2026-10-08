# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Index < View
          include Components::People

          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :editors, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @people.size)) { new_person }
            @people.empty? ? Empty { t(".empty") } : Card(data: { key_list: true }) { @people.each { row(it) } }
            Hint { t(".note") }
            @editors.each { Drawer(**it) }
          end

          private

          def bluesky(person) = person.bluesky_handle && t(".bluesky_handle", handle: person.bluesky_handle)

          def drawer(person) = "#{Drawer.id_for(person)}-drawer"

          def meta(person)
            span(class: "person-row-token") { t(".token", key: person.key) }
            [person.mastodon_handle, bluesky(person)].compact.each { |handle| span { handle } }
          end

          def new_person
            CreateLink(href: path(:admin_new_person), label: t(".new_person"), dialog: drawer(nil))
          end

          def row(person)
            div(class: "person-row", data: { key_row: true }) do
              div(class: "person-row-body") do
                a(
                  class: "person-row-name", href: path(:admin_edit_person, id: person.id),
                  data: { key_open: true, dialog_open: drawer(person) },
                ) { person.name }
                p(class: "person-row-meta") { meta(person) }
              end
              ProfileLinks(person:)
            end
          end
        end
      end
    end
  end
end
