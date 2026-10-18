# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class ImportActs < Component
          def view_template
            Button(href: rules_path, small: true, icon: "fa-solid fa-tag") { t(".rules") }
            ButtonForm(action: path(:admin_sync_issues), label: t(".sync"), icon: "fa-solid fa-rotate")
          end

          private

          def rules_path = "#{path(:admin_settings_tagging)}##{Helpers::TagList::RULES}"
        end
      end
    end
  end
end
