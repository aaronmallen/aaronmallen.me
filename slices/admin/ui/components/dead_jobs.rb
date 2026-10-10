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

          ListItem(title: job.name, href: nil, sub: nil, icon: "fa-solid fa-skull", hover: true) do |item|
            item.body { p(class: "li-sub") { Stamped(text:, at: job.died_at) } }
          end
        end
      end
    end
  end
end
