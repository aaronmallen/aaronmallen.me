# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class Cron < Component
          EMPTY = { "failed" => ".empty.failed", "paused" => ".empty.paused" }.freeze
          FILTERS = Blog::Types::CronFilter.values.to_h { [it, ".filters.#{it}"] }.freeze
          ID = "jobs-cron"
          HEADING = "#{ID}-heading".freeze
          MILLISECONDS = 1000
          RANGES = Blog::Types::AnalyticsRange.values.sort.freeze

          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(Data))
          prop :filter, Blog::Types::CronFilter

          def view_template
            Card(title: t(".heading"), title_id: HEADING, id: ID, aria: { labelledby: HEADING }) do |card|
              card.side { SegmentedLinks(label: t(".filter"), items: FILTERS.keys.map { filter_link(it) }) }
              Hint(class: "jobs-cron-hint") { t(".hint") }
              entries
            end
          end

          private

          def args(entry) = entry.args ? "#{entry.job} #{entry.args.to_json}" : entry.job

          def count(filter) = (@entries.count { kept?(it, filter) } unless filter == "paused" && unknown?)

          def empty_key
            return ".empty.unknown" if @filter == "paused" && unknown?

            EMPTY.fetch(@filter)
          end

          def entries
            shown = @entries.select { kept?(it) }

            shown.empty? ? Empty { t(empty_key) } : shown.each { entry(it) }
          end

          def entry(entry)
            div(id: "#{ID}-#{entry.name}", class: ["jobs-cron-entry", ("jobs-cron-failed" if entry.failed?)]) do
              div(class: "jobs-cron-body") do
                title(entry)
                p(class: "jobs-cron-meta") { schedule(entry) }
                error(entry) if entry.failed?
                p(class: "jobs-cron-meta") { runs(entry) }
              end
              performance_link(entry)
            end
          end

          def error(entry)
            p(class: "jobs-cron-error") do
              b { entry.last[:error_class] }
              plain " #{entry.last[:error_message]}" if entry.last[:error_message]
            end
          end

          def filter_link(filter)
            name = t(FILTERS.fetch(filter))
            found = count(filter)
            query = filter == "all" ? {} : { cron: filter }

            {
              text: found ? t(".filters.counted", name:, count: found) : name,
              href: "#{path(:admin_settings_jobs, **query)}##{ID}", current: filter == @filter,
            }
          end

          def kept?(entry, filter = @filter)
            case filter
              when "failed" then entry.failed?
              when "paused" then entry.paused?
              else true
            end
          end

          def last_run(entry)
            return span { t(".never") } unless entry.last

            text = t(".last", at: Stamped::MARK, took: took(entry.last[:duration]))

            span(class: ("jobs-failed" if entry.failed?)) do
              Stamped(text:, at: entry.last[:occurred_at], format: :short)
            end
          end

          def next_run(entry)
            return span { t(".unknown") } if entry.enabled.nil? || (entry.next_at.nil? && !entry.paused?)
            return span { t(".paused_note") } if entry.paused?

            span { Stamped(text: t(".next", at: Stamped::MARK), at: entry.next_at, format: :short) }
          end

          def performance_link(entry)
            return unless entry.last

            href = "#{path(:admin_performance, range: range(entry))}##{Performance::TimingTable.anchor(entry.job)}"

            Button(href:, small: true, icon: "fa-solid fa-gauge-high", label: t(".performance", name: entry.name))
          end

          def range(entry)
            days = Blog::TimeZone.today - Blog::TimeZone.today(entry.last[:occurred_at]) + 1

            RANGES.find { it >= days } || RANGES.last
          end

          def runs(entry)
            last_run(entry)
            next_run(entry)
          end

          def schedule(entry)
            span { entry.description }
            code(class: "jobs-cron-code") { entry.cron }
            span(class: "jobs-cron-class") { args(entry) }
          end

          def title(entry)
            p(class: "jobs-cron-title") do
              span(class: "jobs-cron-name") { entry.name }
              Pill(color: :pink, icon: "fa-solid fa-xmark") { t(".failed") } if entry.failed?
              Pill(color: :orange, icon: "fa-regular fa-clock") { t(".missed") } if entry.missed?(Time.now)
              Pill(color: nil, icon: "fa-solid fa-pause") { t(".paused") } if entry.paused?
            end
          end

          def took(milliseconds)
            return t(".milliseconds", count: milliseconds.round) if milliseconds < MILLISECONDS

            t(".seconds", count: format("%.1f", milliseconds / MILLISECONDS))
          end

          def unknown? = @entries.any? { it.enabled.nil? }
        end
      end
    end
  end
end
