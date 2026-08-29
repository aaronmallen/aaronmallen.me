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

          def view_template
            div(class: "compose-part", data: { social_part: "" }) do
              Textarea(value: @body, **body_attributes)
              div(class: "compose-part-foot") do
                Counts(counts: @counts, networks: @networks)
                remove_button
              end
            end
          end

          private

          def body_attributes
            {
              class: "compose-body",
              name: "social[parts][]",
              placeholder: t(".placeholder"),
              aria: { label: t(".body") },
              data: { social_body: "" },
            }
          end

          def remove_button
            Button(
              variant: :gh, small: true, hidden: !@removable, aria: { label: t(".remove") },
              data: { social_remove: "" },
            ) do
              i(class: "fa-solid fa-xmark", aria: { hidden: "true" })
            end
          end
        end
      end
    end
  end
end
