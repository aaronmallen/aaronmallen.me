# frozen_string_literal: true

module Admin
  module UI
    module Components
      class LinkCheckPill < Component
        prop :check, Blog::Types::Instance(ROM::Struct).optional

        def view_template
          return Pill(color: nil, icon: "fa-regular fa-clock") { t(".unchecked") } unless @check
          return Pill(color: :green, icon: "fa-solid fa-check") { t(".fine") } unless @check.reason
          return Pill(color: :orange, icon: "fa-solid fa-triangle-exclamation") { t(".failing") } if nights < 2

          Pill(color: :pink, icon: "fa-solid fa-link-slash") { t(".failing_nights", count: nights) }
        end

        private

        def nights = @check.failures
      end
    end
  end
end
