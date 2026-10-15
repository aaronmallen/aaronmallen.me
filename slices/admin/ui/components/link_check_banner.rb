# frozen_string_literal: true

module Admin
  module UI
    module Components
      class LinkCheckBanner < Component
        prop :run, Blog::Types::Instance(ROM::Struct).optional
        prop :return_to, Blog::Types::String

        def view_template
          return unless @run&.stopped_early

          Form(action: path(:admin_run_link_check), class: "post-banner link-check-banner", role: "alert") do
            input(type: "hidden", name: "return_to", value: @return_to)
            Icon("fa-solid fa-triangle-exclamation")
            span(class: "post-banner-text") { t(".stopped", at:, checked: @run.links_checked, due: @run.links_due) }
            Button(type: "submit", small: true, icon: "fa-solid fa-rotate") { t(".run") }
          end
        end

        private

        def at = l(Blog::TimeZone.local(@run.finished_at), format: :short)
      end
    end
  end
end
