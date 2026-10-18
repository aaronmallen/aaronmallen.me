# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class Health < Component
          BAD = "jobs-bad"
          COUNTS = %i[busy enqueued latency scheduled retries dead].to_h { [it, ".counts.#{it}"] }.freeze
          CROWDED = 200
          HEADING = "jobs-health-heading"
          LATE = 60
          STATUSES = %i[down not_seen quiet stopping working].to_h { [it, ".status.#{it}"] }.freeze
          STUCK = 600
          TONES = { working: "jobs-good", quiet: "jobs-calm", stopping: "jobs-warn", not_seen: BAD }.freeze
          WARN = "jobs-warn"

          def self.tone(seconds, late: LATE)
            if seconds >= STUCK then BAD
            elsif seconds >= late then WARN
            end
          end

          prop :health, Blog::Types::Instance(Data)

          def view_template
            section(class: "card jobs-health", aria: { labelledby: HEADING }) do
              @health.down? ? unknown : known
            end
          end

          private

          def busy
            plain @health.busy.to_s
            whitespace
            small { t(".of", concurrency: @health.concurrency) }
          end

          def cell(name, tone = nil, &)
            div(class: ["jobs-count", tone]) do
              b(&)
              span { t(COUNTS.fetch(name)) }
            end
          end

          def counts
            cell(:busy, (WARN if full?)) { busy }
            cell(:enqueued, (WARN if @health.enqueued > CROWDED)) { count(@health.enqueued) }
            cell(:latency, self.class.tone(@health.latency)) { Blog::Helpers::Figures.elapsed(@health.latency) }
            set_counts
          end

          def full? = @health.concurrency.positive? && @health.busy == @health.concurrency

          def known
            status(TONES.fetch(@health.status), t(STATUSES.fetch(@health.status))) { meta }
            div(class: "jobs-counts") { counts }
            Trend(days: @health.days)
          end

          def meta
            span { Stamped(text: t(".beat", at: Stamped::MARK), at: @health.beat) } if @health.beat
            span { t(".processes", count: @health.processes) } if @health.processes.positive?
          end

          def set_counts
            cell(:scheduled) { count(@health.scheduled) }
            cell(:retries, (WARN if @health.retries.positive?)) { count(@health.retries) }
            cell(:dead, (BAD if @health.dead.positive?)) { count(@health.dead) }
          end

          def status(tone, label, &)
            div(class: ["jobs-status", tone]) do
              span(class: "jobs-dot", aria: { hidden: "true" })
              h2(id: HEADING, class: "jobs-status-label") { label }
              p(class: "jobs-status-meta", &) if block_given?
            end
          end

          def unknown
            status(BAD, t(STATUSES.fetch(:down)))
            div(class: "jobs-counts jobs-unknown") do
              COUNTS.each_key { |name| cell(name) { t(".unknown") } }
            end
          end
        end
      end
    end
  end
end
