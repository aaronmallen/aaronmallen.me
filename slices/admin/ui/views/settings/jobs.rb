# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class Jobs < View
          prop :health, Blog::Types::Instance(Data)

          def view_template
            SettingsHead(tab: :jobs, title: t(".heading"))
            div(class: "jobs") do
              Components::Jobs::Warnings(health: @health)
              Components::Jobs::Health(health: @health)
            end
          end
        end
      end
    end
  end
end
