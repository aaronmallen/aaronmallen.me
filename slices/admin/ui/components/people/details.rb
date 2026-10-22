# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Details < Component
          LISTS = %i[emails phones addresses websites chats dates relations].freeze
          MAPS = "https://maps.google.com/?q=%<query>s"
          SECTIONS = {
            contact: %i[emails phones addresses websites chats],
            social: %i[mastodon bluesky mention],
            work: %i[company job_title department],
            personal: %i[nickname birthday dates relations],
          }.freeze
          TEXTS = %i[company job_title department nickname].freeze
          WEB = %r{\Ahttps?://}i

          prop :person, Blog::Types::Instance(ROM::Struct)
          prop :today, Blog::Types::Date

          def view_template
            Card(class: "contact-card") do
              SECTIONS.each { |name, rows| section(name, rows.select { shown?(it) }) }
              custom_fields if @person.custom_fields.any?
              notes if @person.notes
            end
          end

          private

          def addresses
            entries(:addresses) do |address|
              lines = Helpers::ContactText.address_lines(address)
              a(class: "contact-address", href: format(MAPS, query: ERB::Util.url_encode(lines.join(", "))),
                **OUTBOUND) do
                lines.join("\n")
              end
            end
          end

          def birthday
            value do
              span { Helpers::ContactText.day(@person.birthday) }
              years = Helpers::ContactText.age(@person.birthday, @today)
              span(class: "contact-v-type") { t(".years", count: years) } if years
            end
          end

          def bluesky = value { ProfileLinks(person: @person, networks: %w[bluesky]) }

          def chats = entries(:chats) { |chat| span { chat["value"] } }

          def custom_fields
            sec(:custom_fields) do
              @person.custom_fields.each do |field|
                dt { field["key"] }
                dd { value { plain field["value"] } }
              end
            end
          end

          def dates = entries(:dates) { |date| span { Helpers::ContactText.day(date["value"]) } }

          def emails = entries(:emails) { |email| a(href: "mailto:#{email['value']}") { email["value"] } }

          def entries(list)
            @person.public_send(list).each do |entry|
              div(class: "contact-v") do
                yield entry
                span(class: "contact-v-type") { entry["type"] } if entry["type"]
              end
            end
          end

          def mastodon = value { ProfileLinks(person: @person, networks: %w[mastodon]) }

          def mention
            token = t("ui.components.people.row.token", key: @person.key)

            value do
              span(class: "contact-mono") { token }
              CopyButton(value: token, copied: t(".copied"), bare: true, class: "contact-copy") { t(".copy") }
            end
          end

          def notes
            div(class: "contact-sec") do
              h3 { t(".sections.notes") }
              p(class: "contact-notes") { @person.notes }
            end
          end

          def phones = entries(:phones) { |phone| a(href: "tel:#{phone['value'].delete(' ')}") { phone["value"] } }

          def relations = entries(:relations) { |relation| span { relation["value"] } }

          def sec(name, &)
            div(class: "contact-sec") do
              h3 { t([".sections", name].join(".")) }
              dl(class: "contact-dl", &)
            end
          end

          def section(name, rows)
            return if rows.empty?

            sec(name) do
              rows.each do |row|
                dt { t([".rows", row].join(".")) }
                dd { TEXTS.include?(row) ? text(@person.public_send(row)) : __send__(row) }
              end
            end
          end

          def shown?(row)
            case row
              when :mastodon then @person.mastodon_handle
              when :bluesky then @person.bluesky_did
              when :mention then @person.key && (@person.mastodon_handle || @person.bluesky_handle)
              when *LISTS then @person.public_send(row).any?
              else @person.public_send(row)
            end
          end

          def text(content) = value { plain content }

          def value(&) = div(class: "contact-v", &)

          def websites
            entries(:websites) do |site|
              url = site["value"]
              url.match?(WEB) ? a(href: url, **OUTBOUND) { url.sub(WEB, "") } : span { url }
            end
          end
        end
      end
    end
  end
end
