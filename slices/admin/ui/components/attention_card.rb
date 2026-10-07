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

          Card(title: t(".title"), data: { attention: "", key_list: true }) do |card|
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
            Button(href: edit_post_path(row), small: true) { t(".open") }
            snooze(row)
          end
        end

        def edit_post_path(row) = path(:admin_edit_post, id: row.record_id)

        def icon_button(label, icon)
          Button(type: "submit", small: true, title: label, aria: { label: }, icon:)
        end

        def journal(row)
          href = "##{TodayJournalCard::FORM_ID}"

          ListItem(title: t(".journal"), href:, sub: t(".journal_gap", count: row.days)) do
            Button(href:, small: true) { t(".write") }
            snooze(row)
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

        def snooze(row)
          Form(action: path(:admin_snooze_attention)) do
            input(type: "hidden", name: "kind", value: row.kind)
            input(type: "hidden", name: "record_id", value: row.record_id) if row.record_id
            icon_button(t(".snooze"), "fa-solid fa-bell-slash")
          end
        end

        def task(row, sub)
          ListItem(title: row.title, href: path(:admin_task, id: row.record_id, origin: ORIGIN), sub:) do
            move(row)
            cancel(row)
            snooze(row)
          end
        end

        def task_form(route, row, label, icon, data: nil, **params)
          Form(action: path(route, id: row.record_id, **params), data:) do
            input(type: "hidden", name: "origin", value: ORIGIN)
            icon_button(label, icon)
          end
        end
      end
    end
  end
end
