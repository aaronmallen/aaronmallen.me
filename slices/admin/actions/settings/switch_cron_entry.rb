# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class SwitchCronEntry < Action
        CRON = UI::Components::Jobs::Cron::ID
        ENABLE = "enable"
        TOASTS = { true => "settings_page.toasts.cron_enabled", false => "settings_page.toasts.cron_paused" }.freeze
        UNREACHABLE = "settings_page.toasts.unreachable"

        include Deps[switch_cron_entry: "activity.operations.switch_cron_entry"]

        def handle(request, response)
          enabled = request.params[:switch] == ENABLE
          back = back_to_section(request, :admin_settings_jobs, CRON) || "#{routes.path(:admin_settings_jobs)}##{CRON}"

          case switch_cron_entry.call(request.params[:name], enabled:)
            in Failure(:queue_unavailable) then toast_back(response, UNREACHABLE, back)
            in result then settle(response, result, TOASTS.fetch(enabled), back)
          end
        end
      end
    end
  end
end
