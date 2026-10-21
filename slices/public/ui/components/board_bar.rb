# frozen_string_literal: true

module Public
  module UI
    module Components
      class BoardBar < Component
        prop :counts, Blog::Types::Hash.map(Blog::Types::TaskColumn, Blog::Types::Integer)

        def view_template
          div(class: "board-bar") do
            span(class: "meta") { t(".count", open: open_count, total: @counts.values.sum) }
            div(class: "board-switch", role: "group", aria: { label: t(".label") }) do
              switch("board", "fa-solid fa-table-columns")
              switch("list", "fa-solid fa-list")
            end
          end
        end

        private

        def open_count = @counts.except(*Blog::Types::ClosedTaskStatus.values).values.sum

        def switch(view, icon)
          button(type: "button", data: { board_view: view }, aria: { pressed: "false" }) do
            IconLabel(icon:) { t([".views", view].join(".")) }
          end
        end
      end
    end
  end
end
