# frozen_string_literal: true

module Admin
  module UI
    module Components
      class DeadJobs < Component
        DEAD = Blog::Types::JobSetName["dead"]

        prop :dead_jobs, Blog::Types::Array.of(Blog::Types::Instance(::Activity::Structs::SetJob))

        def view_template = @dead_jobs.each { dead_job(it) }

        private

        def dead_job(job)
          text = t(".died", at: Stamped::MARK, error: job.error)
          discard = t(".confirm_discard", job: job.name)

          data = { menu: path(:admin_set_job_menu, set: DEAD, jid: job.jid) }

          ListItem(title: job.name, href: nil, sub: nil, icon: "fa-solid fa-skull", hover: true, data:) do |item|
            item.sub { Stamped(text:, at: job.at) }
            job_form(job, "retry", t(".retry"), "fa-solid fa-rotate-right")
            job_form(job, "discard", t(".discard"), :trash, confirm: discard)
          end
        end

        def job_form(job, act, label, icon, confirm: nil)
          action = path(:admin_act_on_set_job, set: DEAD, jid: job.jid, act:)

          ButtonForm(action:, label:, icon:, icon_only: true, confirm:, hidden: { return_to: path(:admin_root) })
        end
      end
    end
  end
end
