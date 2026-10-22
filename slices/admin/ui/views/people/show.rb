# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Show < View
          include Components::People

          LIVE_TABLES = %w[mail_threads people service_connections].freeze

          prop :person, Blog::Types::Instance(ROM::Struct)
          prop :threads, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :connection, Blog::Types::Instance(ROM::Struct).optional

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            Top(
              person: @person, title: Avatar.name_of(@person), sub:, labels: @person.labels.to_a,
              back: path(:admin_contacts), back_label: t(".back"),
            ) { actions }
            div(class: "g-main") do
              Details(person: @person, today: Blog::TimeZone.local_date(Time.now))
              div(class: "stick contact-side") do
                MailCard(threads: @threads, email:)
                GoogleCard(person: @person, connection: @connection)
              end
            end
          end

          private

          def actions
            if email
              href = path(:admin_mail, compose: Blog::Constants::CHECKED, to: email)
              Button(href:, icon: "fa-regular fa-envelope") { t(".email") }
            end
            star
            Button(href: path(:admin_edit_person, id: @person.id), variant: :pri, icon: :edit) { t(".edit") }
          end

          def email = @person.emails.first&.fetch("value")

          def star
            on = @person.starred

            Form(action: path(:admin_star_person, id: @person.id), class: "contact-star-form") do
              input(type: "hidden", name: "starred", value: on ? Blog::Constants::UNCHECKED : Blog::Constants::CHECKED)
              Button(
                type: "submit", variant: :gh, icon: [on ? "fa-solid" : "fa-regular", "fa-star"],
                class: ("on" if on), aria: { pressed: on.to_s },
              ) { t(on ? ".starred" : ".star") }
            end
          end

          def sub
            text = [@person.job_title, @person.department, @person.company].compact.join(" · ")
            text unless text.empty?
          end
        end
      end
    end
  end
end
