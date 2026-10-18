# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class ActOnSetJob < Action
        GONE = "settings_page.toasts.job_gone"
        UNREACHABLE = "settings_page.toasts.unreachable"

        include Deps[act_on_set_job: "activity.operations.act_on_set_job"]

        def handle(request, response)
          set, jid, act = request.params.to_h.values_at(:set, :jid, :act)
          card = UI::Components::Jobs::Set.id(set)
          back = back_to_section(request, :admin_settings_jobs, card) || "#{routes.path(:admin_settings_jobs)}##{card}"

          case act_on_set_job.call(set, jid, act)
            in Failure(:unknown_act) then halt :not_found
            in Failure(:not_found) then toast_back(response, GONE, back)
            in Failure(:queue_unavailable) then toast_back(response, UNREACHABLE, back)
            in result then settle(response, result, "settings_page.toasts.job_acts.#{act}", back)
          end
        end
      end
    end
  end
end
