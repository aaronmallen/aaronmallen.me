# frozen_string_literal: true

module Admin
  module UI
    module Components
      class StatusPill < Component
        STATUSES = {
          published: [:green, "fa-solid fa-circle-check", ".published"],
          posted: [:green, "fa-solid fa-circle-check", ".posted"],
          approved: [:green, "fa-solid fa-circle-check", ".approved"],
          draft: [:orange, "fa-regular fa-pen-to-square", ".draft"],
          pending: [:orange, "fa-regular fa-clock", ".pending"],
          scheduled: [:blue, "fa-regular fa-clock", ".scheduled"],
          spam: [:pink, "fa-solid fa-ban", ".spam"],
        }.freeze

        prop :status, Blog::Types::Symbol.enum(*STATUSES.keys), &:to_sym

        def view_template
          color, icon, label_key = STATUSES.fetch(@status)

          Pill(color:) do
            IconLabel(icon:) { t(label_key) }
          end
        end
      end
    end
  end
end
