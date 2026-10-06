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

          COUNTS = { OPEN => ".counts.open", RESOLVED => ".counts.resolved", DROPPED => ".counts.dropped" }.freeze
          EMPTIES = { OPEN => ".empty.open", RESOLVED => ".empty.resolved", DROPPED => ".empty.dropped" }.freeze
          FILTERS = {
            OPEN => "ui.views.decisions.index.open",
            RESOLVED => "ui.views.decisions.index.resolved",
            DROPPED => "ui.views.decisions.index.dropped",
          }.freeze
          SEPARATOR = " · "
          TITLES = { OPEN => ".titles.open", RESOLVED => ".titles.resolved", DROPPED => ".titles.dropped" }.freeze

          def initialize(counts:, decisions:, filter:)
            super()
            @counts = counts
            @decisions = decisions
            @filter = filter
          end

          def view_template
            PageHead(title: t(".heading"), sub:) do
              filter_form
              new_link
            end

            Card(title: t(TITLES.fetch(@filter))) { rows }
            Pager(page: @decisions, route: :admin_decisions, params: { status: @filter })
          end

          private

          def filter_form
            FilterSwitch(
              action: path(:admin_decisions),
              name: "status",
              options: FILTERS,
              selected: @filter,
              label: t(".filter"),
            )
          end

          def new_link
            CreateLink(href: path(:admin_new_decision), label: t(".new_decision"))
          end

          def rows
            return Empty { t(EMPTIES.fetch(@filter)) } if @decisions.rows.empty?

            @decisions.rows.each { Row(decision: it) }
          end

          def sub = COUNTS.map { |status, key| t(key, count: @counts.fetch(status, 0)) }.join(SEPARATOR)
        end
      end
    end
  end
end
