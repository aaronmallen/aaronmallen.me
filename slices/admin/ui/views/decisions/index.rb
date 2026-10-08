# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Decisions
        class Index < View
          include Components::Decisions

          DROPPED = Blog::Types::DecisionStatus["dropped"]
          OPEN = Blog::Types::DecisionStatus["open"]
          RESOLVED = Blog::Types::DecisionStatus["resolved"]

          EMPTIES = { OPEN => ".empty.open", RESOLVED => ".empty.resolved", DROPPED => ".empty.dropped" }.freeze

          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :decisions, Blog::Types::Instance(Blog::Structs::Paged)
          prop :filter, Blog::Types::DecisionStatus

          def view_template
            content_for(:title, t(".title"))
            PageHead(title: t(".heading"), sub:) do
              CreateLink(href: path(:admin_new_decision), label: t(".new_decision"))
            end
            StatusTabs(counts: @counts, filter: @filter)

            Card { rows }
            Pager(page: @decisions, route: :admin_decisions, params: { status: @filter })
          end

          private

          def count(status) = @counts.fetch(status, 0)

          def rows
            return Empty { t(EMPTIES.fetch(@filter)) } if @decisions.rows.empty?

            @decisions.rows.each { Row(decision: it) }
          end

          def sub
            return t(EMPTIES.fetch(OPEN)) if count(OPEN).zero?

            t(".waiting", count: count(OPEN), resolved: count(RESOLVED), dropped: count(DROPPED))
          end
        end
      end
    end
  end
end
