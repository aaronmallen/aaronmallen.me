# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Composer < Component
          ACCOUNTS = "social[accounts][]"
          DRAFT = Blog::Types::SocialIntent["draft"]
          MODES = Blog::Types::SocialMode.values.to_h { [it, ".#{it}"] }.freeze
          SEND = Blog::Types::SocialIntent["send"]

          prop :accounts, Blog::Types::Array.of(Blog::Types::Instance(Structs::SocialAccount))
          prop :counts, Blog::Types::Array.of(Blog::Types::Hash)
          prop :errors, Blog::Types::Hash
          prop :handles, Blog::Types::Hash
          prop :networks, Blog::Types::Array.of(Blog::Types::Instance(Structs::Network))
          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :values, Blog::Types::Hash
          prop :editing, Blog::Types::Integer.optional, default: nil
          prop :autofocus, Blog::Types::Bool, default: false

          def view_template
            Form(action: action, data: { social_composer: "" }) do
              Card(title: editing? ? t(".editing") : t(".title"), class: "social-compose") do |card|
                card.side { targets }
                parts
                tools
                schedule_field
                foot
              end
              part_template
            end
          end

          private

          def action = editing? ? path(:admin_update_social_post, id: @editing) : path(:admin_create_social_post)

          def add_button
            Button(variant: :gh, small: true, data: { social_add: "" }, icon: "fa-solid fa-plus") { t(".add") }
          end

          def blank? = @values[:parts].none? { written?(it) }

          def button_label(icon, text_key, **)
            span(class: "bt-label", **) do
              IconLabel(icon:) { t(text_key) }
            end
          end

          def buttons
            cancel_link if editing?
            Button(
              type: "submit", name: "intent", value: DRAFT, small: true, disabled: draft_disabled?,
              data: { social_draft: "" },
            ) do
              button_label("fa-regular fa-floppy-disk", ".save_draft")
            end
            send_button
          end

          def cancel_link = Button(href: path(:admin_social), variant: :gh, small: true) { t(".cancel") }

          def draft_disabled? = blank? || @networks.none?(&:selected)

          def editing? = !@editing.nil?

          def foot
            div(class: "compose-foot") do
              hints
              div(class: "compose-actions") { buttons }
            end
          end

          def hints
            Hint(data: { social_now: "" }, hidden: scheduling?) { t(".hint_now") }
            Hint(data: { social_later: "" }, hidden: !scheduling?) { t(".hint_later") }
          end

          def mode_options = MODES.transform_values { t(it) }

          def over_limit?
            @networks.select(&:selected).any? { |network| @counts.any? { it[network.name]&.over } }
          end

          def part(body, counts, autofocus: false, removable: @values[:parts].size > 1)
            Part(body:, counts:, networks: @networks, removable:, autofocus:)
          end

          def part_template
            template(data: { social_part_template: "" }) { part("", Blog::Constants::EMPTY_HASH, removable: true) }
          end

          def parts
            div(class: "compose-parts", data: { social_parts: "" }) do
              @values[:parts].each_with_index do |body, index|
                part(body, @counts.fetch(index, Blog::Constants::EMPTY_HASH), autofocus: @autofocus && index.zero?)
              end
            end
            Mentions(handles: @handles, people: @people)
            FieldError(field: :parts, errors: @errors)
          end

          def schedule_field
            div(class: "compose-when", data: { social_later: "" }, hidden: !scheduling?) do
              Field(label: t(".schedule_at"), name: :schedule_at, errors: @errors, error: FieldError) do |control|
                Input(type: "datetime-local", **control, name: "social[schedule_at]", value: @values[:schedule_at])
              end
            end
          end

          def scheduling? = @values[:mode] == Blog::Types::SocialMode["schedule"]

          def send_button
            Button(
              variant: :pri, type: "submit", name: "intent", value: SEND, disabled: send_disabled?,
              data: { social_send: "" },
            ) do
              button_label("fa-solid fa-paper-plane", ".post_now", data: { social_now: "" }, hidden: scheduling?)
              button_label("fa-regular fa-clock", ".schedule_now", data: { social_later: "" }, hidden: !scheduling?)
            end
          end

          def send_disabled? = draft_disabled? || over_limit?

          def targets
            Targets(errors: @errors, networks: @accounts, name: ACCOUNTS)
            input(type: "hidden", name: ACCOUNTS, value: "")
          end

          def tools
            div(class: "compose-tools") do
              add_button
              SegmentedControl(label: t(".when"), name: "social[mode]", options: mode_options, selected: @values[:mode])
            end
          end
        end
      end
    end
  end
end
