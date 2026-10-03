# frozen_string_literal: true

module Admin
  module UI
    module Components
      class AttentionCard < Component
        CARRIED = Blog::Types::AttentionKind["carried"]
        DRAFT = Blog::Types::AttentionKind["draft"]
        JOURNAL = Blog::Types::AttentionKind["journal"]
        NEXT = Blog::Types::TaskFilter["next"]
        ORIGIN = Blog::Types::TaskOrigin["today"]
        SOMEDAY = Blog::Types::AttentionKind["someday"]

        prop :rows, Blog::Types::Array.of(Blog::Types::Instance(Data))

        def view_template
          return if @rows.empty?

          Card(title: t(".title"), data: { attention: "" }) do |card|
            card.side { span(class: "meta") { t(".count", count: @rows.size) } }
            @rows.each { row(it) }
          end
        end

        private

        def cancel(row)
          label = t(".cancel")
          data = { confirm: t(".confirm_cancel", task: row.title), confirm_styled: true }

          task_form(:admin_cancel_task, row, label, "fa-solid fa-ban", data:)
        end

        def draft(row)
          ListItem(title: row.title, href: edit_post_path(row), sub: t(".untouched", count: row.days)) do
            a(class: "btn sm", href: edit_post_path(row)) { t(".open") }
          end
        end

        def edit_post_path(row) = path(:admin_edit_post, id: row.record_id)

        def journal(row)
          href = "##{TodayJournalCard::FORM_ID}"

          ListItem(title: t(".journal"), href:, sub: t(".journal_gap", count: row.days)) do
            a(class: "btn sm", href:) { t(".write") }
          end
        end

        def move(row)
          list = t(".lists.next")

          task_form(:admin_move_task, row, t(".move", list:), "fa-solid fa-arrow-right", filter: NEXT)
        end

        def row(row)
          case row.kind
          when CARRIED then task(row, t(".carried", count: row.days))
          when SOMEDAY then task(row, t(".untouched", count: row.days))
          when DRAFT then draft(row)
          when JOURNAL then journal(row)
          end
        end

        def task(row, sub)
          ListItem(title: row.title, href: path(:admin_task, id: row.record_id, origin: ORIGIN), sub:) do
            move(row)
            cancel(row)
          end
        end

        def task_form(route, row, label, icon, data: nil, **params)
          Form(action: path(route, id: row.record_id, **params), data:) do
            input(type: "hidden", name: "origin", value: ORIGIN)
            Button(type: "submit", small: true, title: label, aria: { label: }) do
              i(class: icon, aria: { hidden: "true" })
            end
          end
        end
      end
    end
  end
end
