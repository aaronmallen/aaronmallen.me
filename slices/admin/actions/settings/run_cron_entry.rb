# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class RunCronEntry < Action
        CRON = UI::Components::Jobs::Cron::ID
        QUEUED = "settings_page.toasts.cron_queued"

        include Deps[run_cron_entry: "activity.operations.run_cron_entry"]

        def handle(request, response)
          back = back_to_section(request, :admin_settings_jobs, CRON) || "#{routes.path(:admin_settings_jobs)}##{CRON}"

          settle(response, run_cron_entry.call(request.params[:name]), QUEUED, back)
        end
      end
    end
  end
end
