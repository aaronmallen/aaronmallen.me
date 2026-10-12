# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Scope < Component
          prop :label, Blog::Types::String

          def view_template
            SegmentedControl(
              label: @label, name: "scope", selected: nil, options: { "this" => t(".this"), "all" => t(".all") },
            )
          end
        end
      end
    end
  end
end
