# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class QueueDrawer < Component
          ID = "jobs-queue"
          SHOW = { dialog_show: true }.freeze

          prop :queue, Blog::Types::Instance(Data)

          def view_template
            Dialog(id: ID, title: t(".title", name: @queue.name), class: "wide", hidden: false, data: SHOW) do
              p(class: "jobs-waiting") { t(".waiting", count: @queue.size, formatted: count(@queue.size)) }
              Hint { t(".oldest", for: Blog::Helpers::Figures.elapsed(@queue.latency)) }
              @queue.jobs.rows.each { job(it) }
              pager
            end
          end

          private

          def job(found)
            ListItem(title: found.name, href: nil, sub: nil) do |item|
              item.meta { p(class: "jobs-args", title: found.arguments) { found.arguments } }
              span { Stamped(text: t(".enqueued", at: Stamped::MARK), at: found.at) } if found.at
            end
          end

          def pager
            Pager(
              page: @queue.jobs, route: :admin_settings_jobs, params: { queue: @queue.name }, newer: t(".earlier"),
              older: t(".later"),
            )
          end
        end
      end
    end
  end
end
