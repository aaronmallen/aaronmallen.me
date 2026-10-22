# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class GoogleCard < Component
          PROFILE = "https://contacts.google.com/person/%<id>s"
          RESOURCE = "people/"

          prop :person, Blog::Types::Instance(ROM::Struct)
          prop :connection, Blog::Types::Instance(ROM::Struct).optional

          def view_template
            Card(as: :aside, class: "contact-google") do |card|
              card.heading do
                Icon("fa-brands fa-google contact-google-icon")
                plain t(".title")
              end
              card.side { span(class: ["contact-sync", ("on" if id)]) { t(id ? ".synced" : ".local") } }
              dl(class: "contact-dl") { rows }
              open_link if id
            end
          end

          private

          def id = @person.google_id&.delete_prefix(RESOURCE)

          def open_link
            Button(
              href: format(PROFILE, id:), variant: :gh, small: true, icon: :outbound, class: "contact-google-open",
              **OUTBOUND,
            ) { t(".open") }
          end

          def phonetic
            [@person.phonetic_given_name, @person.phonetic_middle_name, @person.phonetic_family_name].compact.join(" ")
          end

          def row(key, &)
            dt { t(key) }
            dd { div(class: "contact-v", &) }
          end

          def rows
            row(".account") { @connection ? @connection.label : t(".no_account") }
            row(".file_as") { @person.file_as } if @person.file_as
            row(".phonetic") { phonetic } unless phonetic.empty?
            row(".updated") { Moment(at: @person.updated_at, format: :short) }
            row(".resource") { span(class: "contact-mono") { RESOURCE + id } } if id
          end
        end
      end
    end
  end
end
