# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class Running < Component
          LATE = 120

          prop :processes, Blog::Types::Array.of(Blog::Types::Instance(Data))

          def view_template
            empty = t(".none") if @processes.empty?
            busy = @processes.sum { it.jobs.size }

            Card(title: t(".title"), note: t(".busy", count: busy), empty:) do
              @processes.each { process(it) }
            end
          end

          private

          def capacity(found)
            span(class: "jobs-capacity") do
              b { found.jobs.size.to_s }
              whitespace
              plain t(".of", concurrency: found.concurrency)
            end
          end

          def head(found)
            div(class: "jobs-process-head") do
              p(class: "jobs-host") do
                plain found.host
                span { t(".pid", pid: found.pid) }
              end
              state(found)
              capacity(found)
            end
          end

          def job(found)
            ran = Time.now - found.at

            ListItem(title: found.name, href: nil, sub: nil) do |item|
              item.meta { job_meta(found) }
              span(class: ["jobs-ran", Health.tone(ran, late: LATE)]) { Blog::Helpers::Figures.elapsed(ran) }
            end
          end

          def job_meta(found)
            p(class: "jobs-args", title: found.arguments) { found.arguments }
            p(class: "li-sub jobs-meta") do
              span { found.queue }
              span { Stamped(text: t(".started", at: Stamped::MARK), at: found.at) }
            end
          end

          def meta(found)
            p(class: "jobs-meta") do
              span { Stamped(text: t(".started", at: Stamped::MARK), at: found.started_at) }
              span { t(".queues", queues: found.queues.join(", ")) }
              span(class: "jobs-stopping") { t(".finishing", count: found.jobs.size) } if found.stopping?
            end
          end

          def process(found)
            div(class: "jobs-process") do
              head(found)
              meta(found)
              found.jobs.empty? ? Empty { t(".idle") } : div(class: "jobs-busy") { found.jobs.each { job(it) } }
            end
          end

          def state(found)
            if found.stopping? then Pill(color: :orange) { t(".stopping") }
            elsif found.jobs.any? then Pill(color: :green) { t(".working") }
            else Pill(color: :sand) { t(".quiet") }
            end
          end
        end
      end
    end
  end
end
