# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class SightingRow < Component
          include Located

          prop :sighting, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: device(@sighting)) do |item|
              item.meta do
                p(class: "li-sub") do
                  dotted(place(@sighting), t(".calls", count: @sighting.calls), @sighting.last_address)
                end
                p(class: "li-sub") { seen }
              end
            end
          end

          private

          def seen
            Stamped(text: t(".first_seen", time: Stamped::MARK), at: @sighting.first_seen_at)
            plain(DOT)
            Stamped(text: t(".last_seen", time: Stamped::MARK), at: @sighting.last_seen_at)
          end
        end
      end
    end
  end
end
