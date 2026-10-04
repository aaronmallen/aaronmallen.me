# frozen_string_literal: true

module Admin
  module UI
    module Views
      module TimeReport
        class Show < View
          include Components::TimeReport

          def initialize(report:, today:)
            super()
            @report = report
            @today = today
          end

          def view_template
            PageHead(title: t(".heading"), sub:)

            Split do
              Filters(from: @report.from, to: @report.to, by: @report.by, today: @today)
              div(class: "time-main") { Groups(report: @report) }
            end
          end

          private

          def sub
            t(
              ".span",
              from: l(@report.from, format: :medium), to: l(@report.to, format: :medium),
              total: Blog::Figures.hours(@report.seconds),
            )
          end
        end
      end
    end
  end
end
