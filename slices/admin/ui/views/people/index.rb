# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Index < View
          include Components::People

          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :editor, Blog::Types::Hash
          prop :searchable, Blog::Types::Array.of(Blog::Types::NetworkName)

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @people.size)) { new_person }
            div(class: ("g-main" if @searchable.any?)) do
              div(class: "settings-main") { list }
              Finder(networks: @searchable) if @searchable.any?
            end
            Drawer(editor: @editor)
            Drawer()
          end

          private

          def edit(person)
            label = t(".edit", name: person.name)

            Button(
              href: path(:admin_edit_person, id: person.id), small: true, label:,
              icon: "fa-regular fa-pen-to-square", data: { person_edit: true },
            )
          end

          def list
            @people.empty? ? Empty { t(".empty") } : Card(data: { key_list: true }) { @people.each { row(it) } }
          end

          def meta(person)
            span(class: "person-row-token") { t(".token", key: person.key) }
            ProfileLinks(person:)
          end

          def new_person
            CreateLink(href: path(:admin_new_person), label: t(".new_person"), dialog: Drawer.id_for(Drawer::NEW))
          end

          def row(person)
            div(class: "person-row", data: { key_row: true, menu: path(:admin_person_menu, id: person.id) }) do
              div(class: "person-row-body") do
                a(
                  class: "person-row-name", href: path(:admin_edit_person, id: person.id),
                  data: { key_open: true, person_edit: true },
                ) { person.name }
                p(class: "person-row-meta") { meta(person) }
              end
              div(class: "person-row-acts hov") { edit(person) }
            end
          end
        end
      end
    end
  end
end
