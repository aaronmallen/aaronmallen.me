# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Counts < Component
          COUNT = /%\{count\}/
          COUNTS = {
            Blog::Types::NetworkName["bluesky"] => ".bluesky",
            Blog::Types::NetworkName["mastodon"] => ".mastodon",
          }.freeze
          FULL = 100
          LIMIT = /%\{limit\}/

          prop :counts, Blog::Types::Hash
          prop :networks, Blog::Types::Array.of(Blog::Types::Instance(Structs::Network))

          def view_template
            div(class: "compose-counts") { @networks.each { counter(it) } }
          end

          private

          def counter(network)
            measured = @counts.fetch(network.name, Structs::NetworkCount::NONE)
            template = template(network)

            span(class: counter_class(network, measured), data: counter_data(network, template)) do
              span(data: { social_count_text: "" }) { template.sub(COUNT, measured.count.to_s) }
              meter(measured, network.limit)
            end
          end

          def counter_class(network, measured)
            ["compose-count", ("off" unless network.selected), ("over" if network.selected && measured.over)]
          end

          def counter_data(network, template)
            { limit: network.limit, max_bytes: network.max_bytes, social_count: network.name, template: }
          end

          def fill(measured, limit) = measured.over ? FULL : [(measured.count * FULL) / limit, FULL].min

          def meter(measured, limit)
            span(class: "compose-meter") do
              span(class: "compose-meter-fill", style: "width: #{fill(measured, limit)}%", data: { social_meter: "" })
            end
          end

          def template(network) = t(COUNTS.fetch(network.name)).sub(LIMIT, network.limit.to_s)
        end
      end
    end
  end
end
