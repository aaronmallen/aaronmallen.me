# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CompletedCard < Component
          COMPLETED = Blog::Types::TaskTab["completed"]

          prop :query, Blog::Types::String
          prop :range, Blog::Types::Hash
          prop :tasks, Blog::Types::Instance(Blog::Structs::Paged)
          prop :today, Blog::Types::Date

          def view_template
            Card(data: { key_list: true }) do |card|
              card.side { span(class: "card-note") { t(".shown", count: @tasks.rows.size) } }
              if days.empty?
                Empty { t(filtering? ? ".no_match" : ".empty") }
              else
                archived
              end
            end
          end

          private

          def archived
            days.each { |(date, tasks)| CompletedDay(date:, tasks:, today: @today) }
            Pager(page: @tasks, route: :admin_tasks, params:)
          end

          def days = @days ||= @tasks.rows.group_by { Blog::TimeZone.today(it.completed_at) }.to_a

          def filtering? = !@query.empty? || @range.any?

          def params = { filter: COMPLETED, q: (@query unless @query.empty?), **@range }.compact
        end
      end
    end
  end
end
