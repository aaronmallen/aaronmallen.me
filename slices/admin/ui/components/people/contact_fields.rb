# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class ContactFields < Component
          EXTRA = %i[
            name_prefix middle_name name_suffix phonetic_given_name phonetic_middle_name phonetic_family_name file_as
          ].freeze
          NETWORKS = { mastodon_handle: "mastodon", bluesky_handle: "bluesky" }.freeze
          PLACEHOLDERS = {
            name_prefix: "Dr.", given_name: "Ada", family_name: "Lovelace", name_suffix: "Jr.",
            file_as: "Lovelace, Ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social",
          }.freeze
          TYPES = {
            emails: %w[home work other],
            phones: ["mobile", "work", "home", "main", "work fax", "home fax", "pager", "other"],
            websites: ["profile", "blog", "home page", "work", "other"],
            chats: ["Google Chat", "Skype", "Jabber", "QQ", "other"],
            dates: %w[anniversary other],
            relations: [
              "spouse", "partner", "child", "mother", "father", "parent", "brother", "sister", "friend", "relative",
              "manager", "assistant", "reference", "referred by", "other",
            ],
          }.freeze
          YEAR = /\A\d{4}/

          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash

          def view_template
            name_section
            sec(:work) { fields(:company, :job_title, :department) }
            contact
            social
            personal
            more
          end

          private

          def birthday
            value = @values[:birthday]

            type = value.empty? || value.match?(YEAR) ? "date" : "text"

            label = t(".fields.birthday")

            Field(label:, name: :birthday, errors: @errors, error: FieldError, class: "contact-birthday") do |control|
              Input(**control, type:, name: "person[birthday]", value:)
            end
          end

          def contact
            sec(:contact) do
              entries(:emails, type: "email", placeholder: "ada@example.com")
              entries(:phones, type: "tel", placeholder: "+1 555 0100")
              Addresses(rows: @values[:addresses])
              entries(:websites, type: "url", placeholder: "https://")
              entries(:chats, placeholder: t(".username"))
            end
          end

          def entries(list, **)
            Entries(list:, rows: @values[list], types: TYPES.fetch(list, Blog::Constants::EMPTY_ARRAY), errors: @errors,
                    **)
          end

          def extra? = EXTRA.any? { !@values[it].empty? }

          def fields(*names) = div(class: "contact-fields") { names.each { text_field(it) } }

          def handles? = NETWORKS.keys.any? { !@values[it].empty? }

          def key_field
            key = @values[:key]
            hint = t(".key_none")
            hint = t(".key_note", key: key.empty? ? "key" : key) if handles?

            text_field(:key, placeholder: handles? ? "ada" : t(".key_first")) do
              Hint { hint } unless @errors[:key]
            end
          end

          def more
            sec(:more) do
              entries(:custom_fields)
              Field(label: t(".fields.notes"), name: :notes, errors: @errors, error: FieldError) do |control|
                Textarea(**control, name: "person[notes]", rows: 4, value: @values[:notes])
              end
            end
          end

          def more_toggle
            on = extra?

            button(
              type: "button", class: "contact-more", aria: { expanded: on.to_s },
              data: { contact_more: "", contact_more_on: t(".fewer"), contact_more_off: t(".more") },
            ) { t(on ? ".fewer" : ".more") }
          end

          def name_section
            sec(:name) do
              fields(:name_prefix, :given_name, :middle_name, :family_name, :name_suffix)
              fields(:phonetic_given_name, :phonetic_middle_name, :phonetic_family_name)
              fields(:nickname, :file_as)
              FieldError(field: :name, errors: @errors)
              more_toggle
            end
          end

          def network(name)
            net = NETWORKS[name]
            net ? { class: "field-net #{net}", icon: Blog::Constants::NETWORK_ICONS.fetch(net) } : Blog::Constants::EMPTY_HASH
          end

          def personal
            sec(:personal) do
              birthday
              entries(:dates, type: "date")
              entries(:relations, placeholder: t(".relation"))
            end
          end

          def sec(name)
            div(class: "contact-sec") do
              h3 { t([".sections", name].join(".")) }
              yield
            end
          end

          def social
            sec(:social) do
              div(class: "contact-fields") { NETWORKS.each_key { text_field(it) } }
              key_field
            end
          end

          def text_field(name, placeholder: PLACEHOLDERS[name], &)
            extra = EXTRA.include?(name)

            Field(
              label: t([".fields", name].join(".")), name:, errors: @errors, error: FieldError, **network(name),
              hidden: extra && !extra?, data: ({ contact_extra: "" } if extra),
            ) do |control, field|
              Input(**control, name: "person[#{name}]", value: @values[name], placeholder:, autocomplete: "off")
              field.after(&) if block_given?
            end
          end
        end
      end
    end
  end
end
