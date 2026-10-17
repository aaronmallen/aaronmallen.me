# frozen_string_literal: true

module Admin
  module UI
    module Components
      class DeadJobs < Component
        prop :dead_jobs, Blog::Types::Array.of(Blog::Types::Instance(Data))

        def view_template = @dead_jobs.each { dead_job(it) }

        private

        def dead_job(job)
          text = t(".died", at: Stamped::MARK, error: job.error)
          discard = t(".confirm_discard", job: job.name)

          data = { menu: path(:admin_dead_job_menu, jid: job.jid) }

          ListItem(title: job.name, href: nil, sub: nil, icon: "fa-solid fa-skull", hover: true, data:) do |item|
            item.sub { Stamped(text:, at: job.died_at) }
            job_form(:admin_retry_dead_job, job, t(".retry"), "fa-solid fa-rotate-right")
            job_form(:admin_discard_dead_job, job, t(".discard"), :trash, confirm: discard)
          end
        end

        def job_form(route, job, label, icon, confirm: nil)
          ButtonForm(action: path(route, jid: job.jid), label:, icon:, icon_only: true, confirm:)
        end
      end
    end
  end
end
