# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Index < View
          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @people.size)) { new_person }
            @people.empty? ? Empty { t(".empty") } : Card(data: { key_list: true }) { @people.each { row(it) } }
            Hint { t(".note") }
          end

          private

          def bluesky(person) = person.bluesky_handle && t(".bluesky_handle", handle: person.bluesky_handle)

          def new_person
            CreateLink(href: path(:admin_new_person), label: t(".new_person"))
          end

          def row(person)
            ListItem(title: person.name, href: path(:admin_edit_person, id: person.id), sub: sub(person)) do |item|
              item.beside { Components::People::ProfileLinks(person:) }
            end
          end

          def sub(person)
            dotted(t(".token", key: person.key), person.mastodon_handle, bluesky(person))
          end
        end
      end
    end
  end
end
