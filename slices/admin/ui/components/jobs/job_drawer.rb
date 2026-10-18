# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class JobDrawer < Component
          ID = "jobs-job"
          SETS = Blog::Types::JobSetName.values.to_h { [it, ".sets.#{it}"] }.freeze
          TIMES = [*Blog::Types::JobSetName.values, "created", "enqueued", "failed", "retried"]
                  .to_h { [it.to_sym, ".times.#{it}"] }.freeze

          prop :job, Blog::Types::Instance(Data)

          def view_template
            title = t(".title", set: t(SETS.fetch(@job.set)), jid: @job.jid)

            Dialog(id: ID, title:, class: "wide", hidden: false, data: QueueDrawer::SHOW) do |dialog|
              dialog.foot { SetActs(job: @job, return_to: request.fullpath) }
              body
            end
          end

          private

          def arguments
            p(class: "jobs-label") { t(".arguments") }
            pre(class: "jobs-pre") { JSON.pretty_generate(@job.args) }
          end

          def backtrace
            details(class: "jobs-backtrace", open: true) do
              summary do
                plain t(".backtrace")
                span { t(".lines", count: @job.backtrace.size) }
              end
              pre(class: "jobs-pre") { @job.backtrace.join("\n") }
            end
          end

          def body
            p(class: "jobs-job-name") { @job.name }
            error if @job.error?
            dl(class: "jobs-facts") { facts }
            arguments
            backtrace if @job.backtrace
          end

          def error
            p(class: "jobs-error jobs-error-full") do
              b { @job.error_class }
              plain " #{@job.error_message}" if @job.error_message
            end
          end

          def fact(label, &)
            dt { label }
            dd(&)
          end

          def facts
            fact(t(".jid")) { @job.jid }
            fact(t(".queue")) { @job.queue }
            fact(t(".retries")) { t(".retried", count: @job.retries, max: @job.max_retries) } if @job.retries
            times
          end

          def times = @job.times.each { |name, at| fact(t(TIMES.fetch(name))) { Moment(at:) } }
        end
      end
    end
  end
end
