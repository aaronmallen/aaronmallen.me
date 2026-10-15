# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TimeReport
        class Groups < Component
          HINTS = { "tag" => ".over_tag" }.freeze
          TITLES = { "project" => ".by_project", "tag" => ".by_tag", "day" => ".by_day" }.freeze

          prop :report, Blog::Types::Instance(::Tasks::Structs::TimeReport)

          def view_template
            Card(title: t(TITLES.fetch(@report.by)), id: "time-groups") do |card|
              card.side { span(class: "time-total") { Blog::Helpers::Figures.hours(@report.seconds) } }
              rows
            end
          end

          private

          def over? = @report.groups.sum(&:seconds) > @report.seconds || @report.groups.any?(&:overlapped)

          def rows
            return Empty { t(".empty") } if @report.groups.empty?

            @report.groups.each { Row(group: it, by: @report.by, top:) }
            Hint { t(HINTS.fetch(@report.by, ".over")) } if over?
          end

          def top = @top ||= @report.groups.map(&:seconds).max
        end
      end
    end
  end
end
