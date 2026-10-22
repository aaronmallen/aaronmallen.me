# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Row < Component
          prop :person, Blog::Types::Instance(ROM::Struct)

          def self.sub(person) = [person.job_title, person.company].compact.join(" · ")

          def view_template
            div(class: "contact-row", data: { key_row: true, menu: path(:admin_person_menu, id: @person.id) }) do
              Avatar(person: @person)
              div(class: "contact-row-body") do
                title
                p(class: "contact-row-meta") { meta }
              end
              div(class: "contact-row-acts hov") { edit }
            end
          end

          private

          def edit
            Button(href: path(:admin_edit_person, id: @person.id), small: true, label: t(".edit", name:), icon: :edit)
          end

          def email
            first, *more = @person.emails.map { it["value"] }
            return span(class: "contact-row-none") { envelope { t(".no_email") } } unless first

            a(class: "contact-row-email", href: "mailto:#{first}") do
              envelope { first }
              span(class: "contact-row-more") { t(".more", count: more.size) } if more.any?
            end
          end

          def envelope(&) = IconLabel(icon: "fa-regular fa-envelope", &)

          def meta
            email
            ProfileLinks(person: @person)
            @person.labels.each { |label| span(class: "tag") { "##{label}" } }
          end

          def name = Avatar.name_of(@person)

          def title
            sub = self.class.sub(@person)

            p(class: "contact-row-title") do
              a(class: "contact-row-name", href: path(:admin_person, id: @person.id), data: { key_open: true }) { name }
              Icon("fa-solid fa-star contact-star", label: t(".starred")) if @person.starred
              span(class: "contact-row-sub") { sub } unless sub.empty?
            end
          end
        end
      end
    end
  end
end
