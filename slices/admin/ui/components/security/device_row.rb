# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class DeviceRow < Component
          include Located

          prop :device, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: name) do |item|
              item.meta do
                p(class: "li-sub") { dotted(SignInRow::PROVIDERS[@device.provider], place(@device), @device.address) }
                p(class: "li-sub") { Moment(at: @device.last_signed_in_at) }
              end
              status
            end
          end

          private

          def name = device(@device)

          def sign_out_form
            ButtonForm(
              action: path(:admin_sign_out_device, id: @device.id), label: t(".sign_out"), variant: :warn,
              confirm: t(".confirm_sign_out", device: name),
            )
          end

          def signed_out? = !@device.signed_out_at.nil? && @device.signed_out_at >= @device.last_signed_in_at

          def status
            return Pill { t(".signed_out") } if signed_out?

            Pill(color: :green) { t(".signed_in") }
            sign_out_form
          end
        end
      end
    end
  end
end
