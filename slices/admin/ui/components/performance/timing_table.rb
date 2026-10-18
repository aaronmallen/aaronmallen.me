# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Performance
        class TimingTable < Component
          BROWSER = %i[load_p50 load_p95 lcp_p50 lcp_p95].freeze
          BROWSER_VERB = "GET"
          SERVER = %i[p50 p95 count query_count query_time].freeze
          HEADINGS = (SERVER + BROWSER).to_h { [it, ".columns.#{it}"] }.freeze

          prop :heading, Blog::Types::String
          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)
          prop :browser, Blog::Types::Bool, default: false
          prop :anchors, Blog::Types::Bool, default: false

          def self.anchor(job) = "job-#{job.downcase.gsub('::', '-')}"

          def view_template(&)
            div(class: "tbl-scroll") do
              table(class: "tbl perf-table") do
                thead do
                  groups if @browser
                  headings
                end
                tbody { @rows.each { row(it, &) } }
              end
            end
          end

          private

          def browser_cells(entry)
            unless entry[:verb] == BROWSER_VERB
              return td(class: "tbl-c perf-browser perf-na", colspan: BROWSER.size) do
                span(class: "sr-only") { t(".get_only") }
              end
            end

            BROWSER.each_with_index do |column, index|
              td(class: ["tbl-c num", ("perf-browser" if index.zero?)]) { figure(column, entry.dig(:browser, column)) }
            end
          end

          def browser_heading(column, index)
            th(class: ["tbl-h num", ("perf-browser" if index.zero?)]) { t(HEADINGS.fetch(column)) }
          end

          def column_class(column) = ("perf-key-col" if column == :p95)

          def figure(column, value)
            return t(".none") if value.nil?
            return Blog::Helpers::Figures.count(value) if column == :count
            return format("%.1f", value) if column == :query_count

            t(".ms", value: Blog::Helpers::Figures.count(value.round))
          end

          def groups
            tr do
              td
              th(class: "tbl-h perf-group", colspan: SERVER.size + 1) { t(".server") }
              th(class: "tbl-h perf-group perf-browser", colspan: BROWSER.size) { t(".browser") }
            end
          end

          def headings
            tr do
              th(class: "tbl-h") { @heading }
              th(class: "tbl-h") { t(".spread") }
              SERVER.each { |column| th(class: ["tbl-h num", column_class(column)]) { t(HEADINGS.fetch(column)) } }
              BROWSER.each_with_index { |column, index| browser_heading(column, index) } if @browser
            end
          end

          def row(entry, &)
            tr(id: (self.class.anchor(entry[:job]) if @anchors)) do
              td(class: "tbl-c") { yield(entry) }
              td(class: "tbl-c") { spread(entry) }
              SERVER.each { |column| td(class: ["tbl-c num", column_class(column)]) { figure(column, entry[column]) } }
              browser_cells(entry) if @browser
            end
          end

          def slowest = @slowest ||= @rows.map { it[:p95] }.max

          def spread(entry)
            span(class: "perf-spread", aria: { hidden: "true" }) do
              i(class: "perf-fill-95", style: width(entry[:p95]))
              i(class: "perf-fill-50", style: width(entry[:p50]))
            end
          end

          def width(value)
            share = slowest.positive? ? Math.sqrt(value / slowest) * Blog::Helpers::Figures::PERCENT : 0

            "width: #{share.round}%"
          end
        end
      end
    end
  end
end
