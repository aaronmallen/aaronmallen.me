# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Signature < Component
          prop :scope, Blog::Types::String
          prop :senders, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :from, Blog::Types::Integer.optional
          prop :on, Blog::Types::Bool

          def view_template
            return if @senders.none?(&:signature)

            div(class: "mail-sig") do
              input(type: "checkbox", id:, name: "mail[signature]", value: Blog::Constants::CHECKED, checked: @on)
              @senders.each { signature(it) }
              label(class: "mail-sig-off", for: id, title: t(".remove")) do
                Icon(:close)
                span(class: "sr-only") { t(".remove") }
              end
              label(class: "mail-sig-on", for: id) { t(".add") }
            end
          end

          private

          def id = "#{@scope}-signature"

          def signature(sender)
            div(class: "mail-sig-text", data: { mail_signature: sender.id }, hidden: sender.id != @from) do
              raw(safe(sender.signature.to_s))
            end
          end
        end
      end
    end
  end
end
