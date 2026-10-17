# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Today
        class DeadJobs < View
          prop :count, Blog::Types::Integer
          prop :jobs, Blog::Types::Instance(Blog::Structs::Paged)

          def view_template
            PageHead(title: t(".heading"), sub: t(".count", count: @count))
            Card(empty: (t(".empty") if @jobs.rows.empty?), data: { key_list: true }) do
              DeadJobs(dead_jobs: @jobs.rows)
            end
            Pager(page: @jobs, route: :admin_dead_jobs)
          end
        end
      end
    end
  end
end
