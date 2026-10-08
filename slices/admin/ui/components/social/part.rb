# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Part < Component
          prop :body, Blog::Types::String
          prop :counts, Blog::Types::Hash
          prop :networks, Blog::Types::Array.of(Blog::Types::Instance(Structs::Network))
          prop :removable, Blog::Types::Bool, default: false
          prop :autofocus, Blog::Types::Bool, default: false

          def view_template
            div(class: "compose-part", data: { social_part: "" }) do
              div(class: "compose-part-head", data: { label: t(".label") }) { remove_button }
              Textarea(value: @body, **body_attributes)
              Counts(counts: @counts, networks: @networks)
              preview
            end
          end

          private

          def body_attributes
            {
              class: "compose-body",
              name: "social[parts][]",
              placeholder: t(".placeholder"),
              aria: { label: t(".body") },
              autofocus: @autofocus,
              data: { social_body: "" },
            }
          end

          def preview
            div(class: "compose-preview", hidden: !previewing?, data: { social_preview: "" }) do
              p(class: "compose-preview-head") { t(".preview") }
              @networks.each { preview_line(it) }
            end
          end

          def preview_line(network)
            p(class: "compose-preview-line", hidden: !network.selected, data: { social_preview_line: network.name }) do
              span(class: "compose-preview-network") { network.label }
              span(class: "compose-preview-text", data: { social_preview_text: "" }) { preview_text(network) }
            end
          end

          def preview_text(network) = @counts.fetch(network.name, Structs::NetworkCount::NONE).text

          def previewing? = @body.match?(::Social::Operations::ResolveMentions::TOKEN) && @networks.any?(&:selected)

          def remove_button
            Button(variant: :gh, small: true, hidden: !@removable, data: { social_remove: "" }) { t(".remove") }
          end
        end
      end
    end
  end
end
