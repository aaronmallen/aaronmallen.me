# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Security
        class SightingRow < Component
          include Located

          prop :sighting, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title:) do |item|
              item.meta do
                p(class: "li-sub") do
                  dotted(place(@sighting), t(".calls", count: @sighting.calls), @sighting.last_address)
                end
                p(class: "li-sub") { seen }
              end
            end
          end

          private

          def product = @sighting.last_user_agent[%r{\A\s*([^\s/()]+(?:/[^\s()]+)?)}, 1]&.sub("/", " ")

          def seen
            Dotted do |line|
              line.part { Stamped(text: t(".first_seen", time: Stamped::MARK), at: @sighting.first_seen_at) }
              line.part { Stamped(text: t(".last_seen", time: Stamped::MARK), at: @sighting.last_seen_at) }
            end
          end

          def title = known(dotted(@sighting.browser || product, @sighting.os), :unknown_device)
        end
      end
    end
  end
end
