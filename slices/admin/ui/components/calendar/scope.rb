# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Scope < Component
          prop :label, Blog::Types::String
          prop :selected, Blog::Types::String.optional, default: nil

          def view_template
            SegmentedControl(
              label: @label, name: "scope", selected: @selected, options: { "this" => t(".this"), "all" => t(".all") },
            )
          end
        end
      end
    end
  end
end
