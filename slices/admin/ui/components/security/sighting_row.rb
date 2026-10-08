# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class SightingRow < Component
          prop :sighting, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: device) do |item|
              item.meta do
                p(class: "li-sub") { dotted(place, t(".calls", count: @sighting.calls), @sighting.last_address) }
                p(class: "li-sub") { seen }
              end
            end
          end

          private

          def country = @sighting.country_name || @sighting.country

          def device = dotted(@sighting.browser, @sighting.os).then { it.empty? ? t(".unknown_device") : it }

          def place = dotted(@sighting.city, country).then { it.empty? ? t(".unknown_place") : it }

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
