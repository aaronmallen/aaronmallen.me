# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class StatusPill < Component
          ACTIVE = [:green, "fa-solid fa-circle-check", ".active"].freeze
          ARCHIVED = [nil, "fa-solid fa-box-archive", ".archived"].freeze

          prop :archived, Blog::Types::Bool

          def view_template
            color, icon, label_key = @archived ? ARCHIVED : ACTIVE

            Pill(color:, icon:) { t(label_key) }
          end
        end
      end
    end
  end
end
