# frozen_string_literal: true

module Admin
  module UI
    module Views
      module TimeReport
        class Show < View
          include Components::TimeReport

          prop :report, Blog::Types::Instance(::Tasks::Structs::TimeReport)
          prop :today, Blog::Types::Date

          def view_template
            PageHead(title: t(".heading"), sub:)

            Filters(from: @report.from, to: @report.to, by: @report.by, today: @today)
            Groups(report: @report)
          end

          private

          def sub
            t(
              ".span",
              from: l(@report.from, format: :medium), to: l(@report.to, format: :medium),
              total: Blog::Helpers::Figures.hours(@report.seconds),
            )
          end
        end
      end
    end
  end
end
