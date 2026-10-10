# frozen_string_literal: true

module Admin
  module UI
    module Components
      class AttentionCard < Component
        BROKEN_LINK = Blog::Types::AttentionKind["broken_link"]
        CARRIED = Blog::Types::AttentionKind["carried"]
        DRAFT = Blog::Types::AttentionKind["draft"]
        JOURNAL = Blog::Types::AttentionKind["journal"]
        NEW_DEVICE = Blog::Types::AttentionKind["new_device"]
        NEXT = Blog::Types::TaskFilter["next"]
        ORIGIN = Blog::Types::TaskOrigin["today"]
        SOMEDAY = Blog::Types::AttentionKind["someday"]

        prop :rows, Blog::Types::Array.of(Blog::Types::Instance(Data))
        prop :failures, Blog::Types::Array.of(Blog::Types::Hash)
        prop :dead_jobs, Blog::Types::Array.of(Blog::Types::Instance(Data))
        prop :failed_social_posts, Blog::Types::Array.of(Blog::Types::SocialPostStatus)
        prop :inbox, Blog::Types::Integer
        prop :webmentions, Blog::Types::Integer

        def view_template
          return if total.zero?

          Card(title: t(".title"), class: "today-need", data: { attention: "", key_list: true }) do |card|
            card.side { span(class: "meta") { total.to_s } }
            SyncFailures(failures: @failures)
            DeadJobs(dead_jobs: @dead_jobs)
            AttentionLines(failed_social_posts: @failed_social_posts, inbox: @inbox, webmentions: @webmentions)
            @rows.each { row(it) }
          end
        end

        private

        def broken_link(row) = post(row, row.post_id, row.url, "fa-solid fa-link-slash", row.reason)

        def cancel(row)
          data = { confirm: t(".confirm_cancel", task: row.title) }
          task_form(:admin_cancel_task, row, t(".cancel"), "fa-solid fa-ban", data:)
        end

        def draft(row) = post(row, row.record_id, t(".untouched", count: row.days), "fa-regular fa-file-lines")

        def icon_button(label, icon)
          Button(type: "submit", small: true, title: label, aria: { label: }, icon:)
        end

        def icon_link(href, label, icon, **)
          Button(href:, small: true, title: label, aria: { label: }, icon:, **)
        end

        def journal(row)
          href = path(:admin_journal, write: Blog::Constants::CHECKED)
          link = { data: { dialog_open: Journal::WriteDialog::ID } }
          sub = t(".journal_gap", count: row.days)

          ListItem(title: t(".journal"), href:, link:, sub:, icon: "fa-solid fa-feather", hover: true) do
            icon_link(href, t(".write"), "fa-solid fa-feather", **link)
            snooze(row)
          end
        end

        def move(row)
          list = t(Helpers::TaskLists.title(NEXT))

          task_form(:admin_move_task, row, t(".move", list:), "fa-solid fa-arrow-right", filter: NEXT)
        end

        def new_device(row)
          sub = t(".first_seen", count: row.days)

          ListItem(title: row.title, href: nil, sub:, icon: "fa-solid fa-shield-halved", hover: true) do
            icon_link(path(:admin_security), t(".open_security"), "fa-solid fa-shield-halved")
            snooze(row)
          end
        end

        def post(row, id, sub, icon, reason = nil)
          href = path(:admin_edit_post, id:)

          ListItem(title: row.title, href:, sub:, icon:, hover: true) do |item|
            item.meta { p(class: "li-sub") { reason } } if reason
            icon_link(href, t(".open"), "fa-regular fa-pen-to-square")
            snooze(row)
          end
        end

        def row(row)
          case row.kind
            when CARRIED then task(row, t(".carried", count: row.days), "fa-solid fa-rotate-left")
            when SOMEDAY then task(row, t(".untouched", count: row.days), "fa-regular fa-hourglass")
            when DRAFT then draft(row)
            when JOURNAL then journal(row)
            when NEW_DEVICE then new_device(row)
            when BROKEN_LINK then broken_link(row)
          end
        end

        def snooze(row)
          Form(action: path(:admin_snooze_attention)) do
            input(type: "hidden", name: "kind", value: row.kind)
            input(type: "hidden", name: "record_id", value: row.record_id) if row.record_id
            icon_button(t(".snooze"), "fa-solid fa-bell-slash")
          end
        end

        def task(row, sub, icon)
          href = path(:admin_task, id: row.record_id, origin: ORIGIN)

          ListItem(title: row.title, href:, sub:, icon:, hover: true) do
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

        def total
          lines = [@inbox, @failed_social_posts.size, @webmentions].count(&:positive?)

          @rows.size + @failures.size + @dead_jobs.size + lines
        end
      end
    end
  end
end
