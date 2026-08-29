# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Composer < Component
          DRAFT = Blog::Types::SocialIntent["draft"]
          MODES = Blog::Types::SocialMode.values.to_h { [it, ".#{it}"] }.freeze
          SEND = Blog::Types::SocialIntent["send"]
          WRITING = /\S/

          prop :counts, Blog::Types::Array.of(Blog::Types::Hash)
          prop :errors, Blog::Types::Hash
          prop :networks, Blog::Types::Array.of(Blog::Types::Instance(Structs::Network))
          prop :values, Blog::Types::Hash
          prop :editing, Blog::Types::Integer.optional, default: nil

          def view_template
            Form(action: action, data: { social_composer: "" }) do
              Card(label: t(".label"), title: editing? ? t(".editing") : t(".title")) do
                parts
                Targets(errors: @errors, networks: @networks)
                timing
                foot
              end
              part_template
            end
          end

          private

          def action = editing? ? path(:admin_update_social_post, id: @editing) : path(:admin_create_social_post)

          def add_button
            Button(small: true, data: { social_add: "" }) do
              i(class: "fa-solid fa-plus", aria: { hidden: "true" })
              span { t(".add") }
            end
          end

          def blank? = @values[:parts].none? { it.match?(WRITING) }

          def button_label(icon, text_key, **)
            span(class: "btn-label", **) do
              i(class: icon, aria: { hidden: "true" })
              span { t(text_key) }
            end
          end

          def buttons
            cancel_link if editing?
            Button(
              type: "submit", name: "intent", value: DRAFT, disabled: draft_disabled?, data: { social_draft: "" },
            ) do
              button_label("fa-regular fa-floppy-disk", ".save_draft")
            end
            send_button
          end

          def cancel_link
            a(class: "btn sm", href: path(:admin_social)) { t(".cancel") }
          end

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

          def part(body, counts, removable)
            Part(body:, counts:, networks: @networks, removable:)
          end

          def part_template
            template(data: { social_part_template: "" }) { part("", Dry::Core::Constants::EMPTY_HASH, true) }
          end

          def parts
            div(class: "compose-parts", data: { social_parts: "" }) do
              @values[:parts].each_with_index do |body, index|
                part(body, @counts.fetch(index, Dry::Core::Constants::EMPTY_HASH), @values[:parts].size > 1)
              end
            end
            div(class: "compose-add") { add_button }
            FieldError(field: :parts, errors: @errors)
          end

          def schedule_field
            div(data: { social_later: "" }, hidden: !scheduling?) do
              Field(label: t(".schedule_at"), id: FieldError.id_for(:schedule_at)) do
                Input(
                  type: "datetime-local", id: FieldError.id_for(:schedule_at), name: "social[schedule_at]",
                  value: @values[:schedule_at],
                )
                FieldError(field: :schedule_at, errors: @errors)
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

          def timing
            div(class: "compose-when") do
              SegmentedControl(label: t(".when"), name: "social[mode]", options: mode_options, selected: @values[:mode])
              schedule_field
            end
          end
        end
      end
    end
  end
end
