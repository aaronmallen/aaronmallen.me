# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class DeviceRow < Component
          include Located

          prop :device, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: device(@device)) do |item|
              item.meta do
                p(class: "li-sub") { dotted(SignInRow::PROVIDERS[@device.provider], place(@device), @device.address) }
                p(class: "li-sub") { Moment(at: @device.last_signed_in_at) }
              end
              Pill(color: :green) { t(".signed_in") }
            end
          end
        end
      end
    end
  end
end
