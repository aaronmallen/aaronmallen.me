# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MessageLabel < Component
        COUNT = "{count}"
        DATA = { message_label: true }.freeze
        NAME = "{name}"

        prop :message, Blog::Types::Instance(ROM::Struct)
        prop :filter, Blog::Types::String
        prop :narrowed, Blog::Types::Hash
        prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

        def view_template
          Button(small: true, data: { dialog_open: dialog_id }) { t(".open") }
          Dialog(
            id: dialog_id, title_id: "#{dialog_id}-title", title: t(".title", subject: @message.subject),
            data: { dialog: true },
          ) do
            Form(action: path(:admin_label_message, id: @message.id), class: "label-form", data: DATA) do
              input(type: "hidden", name: "filter", value: @filter)
              HiddenFields(values: @narrowed)
              find
              list
              foot
            end
          end
        end

        private

        def choice(tag)
          label(class: "choice label-choice", data: { message_label_choice: tag&.name }) do
            input(class: "check", type: "checkbox", name: "tags[]", value: tag&.name, checked: tag && on?(tag))
            tag ? Tag(tag:, link: false) : span(class: "tag")
          end
        end

        def create
          Button(
            variant: :gh, small: true, icon: "fa-solid fa-plus", hidden: true,
            data: { message_label_create: t(".create", name: NAME) },
          ) { span }
        end

        def dialog_id = "label-message-#{@message.id}"

        def find
          Input(
            name: "name", autocomplete: "off", autofocus: true, placeholder: t(".find"),
            aria: { label: t(".find_label") }, data: { message_label_find: true },
          )
        end

        def foot
          div(class: "dialog-foot") do
            span(class: "label-count", data: { message_label_count: t(".count", count: COUNT) }) do
              t(".count", count: on_count)
            end
            Button(variant: :gh, small: true, data: { dialog_close: true }) { t(".cancel") }
            Button(type: "submit", variant: :pri, small: true) { t(".save") }
          end
        end

        def list
          div(class: "label-list") do
            @tags.each { choice(it) }
            template(data: { message_label_template: true }) { choice(nil) }
            create
            p(class: "field-error", hidden: true, data: { message_label_bad: true }) { t(".bad") }
            Hint(hidden: @tags.any?, data: { message_label_empty: true }) { t(".empty") }
          end
        end

        def on?(tag) = @message.tags.any? { it.name == tag.name }

        def on_count = @tags.count { on?(it) }
      end
    end
  end
end
