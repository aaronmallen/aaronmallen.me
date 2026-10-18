# frozen_string_literal: true

module Admin
  module UI
    module Components
      class AttentionCard < Component
        NEXT = Blog::Types::TaskFilter["next"]
        ORIGIN = Blog::Types::TaskOrigin["today"]
        JOURNAL_ICON = "fa-solid #{Blog::Helpers::RecordKinds.icon('journal_entry')}".freeze

        prop :rows, Blog::Types::Array.of(Blog::Types::Instance(Data))
        prop :failures, Blog::Types::Array.of(Blog::Types::Hash)
        prop :dead_jobs, Blog::Types::Array.of(Blog::Types::Instance(Data))
        prop :broken_links, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
        prop :failed_social_posts, Blog::Types::Array.of(Blog::Types::SocialPostStatus)
        prop :inbox, Blog::Types::Integer
        prop :more_dead_jobs, Blog::Types::Integer
        prop :webmentions, Blog::Types::Integer

        def view_template
          return if total.zero?

          Card(title: t(".title"), note: total.to_s, class: "today-need", data: { attention: "", key_list: true }) do
            SyncFailures(failures: @failures)
            DeadJobs(dead_jobs: @dead_jobs)
            AttentionLines(
              broken_links: @broken_links, failed_social_posts: @failed_social_posts, inbox: @inbox,
              more_dead_jobs: @more_dead_jobs, webmentions: @webmentions,
            )
            @rows.each { row(it) }
          end
        end

        private

        def broken_link(row) = post(row, row.post_id, row.url, "fa-solid fa-link-slash", row.reason)

        def cancel(row)
          data = { confirm: t(".confirm_cancel", task: row.title) }
          task_form(:admin_cancel_task, row, t(".cancel"), :ban, data:)
        end

        def carried(row) = task(row, t(".carried", count: row.days), "fa-solid fa-rotate-left")

        def draft(row) = post(row, row.record_id, t(".untouched", count: row.days), "fa-regular fa-file-lines")

        def hovered(row) = { hover: true, data: { menu: path(:admin_attention_menu, **identity(row)) } }

        def icon_button(label, icon) = Button(type: "submit", small: true, label:, icon:)

        def icon_link(href, label, icon, **)
          Button(href:, small: true, label:, icon:, **)
        end

        def identity(row) = { kind: row.kind, record_id: row.record_id }.compact

        def journal(row)
          href = path(:admin_journal, write: Blog::Constants::CHECKED)
          link = Dialog.opens(Journal::WriteDialog::ID)
          sub = t(".journal_gap", count: row.days)

          ListItem(title: t(".journal"), href:, link:, sub:, icon: JOURNAL_ICON, **hovered(row)) do
            icon_link(href, t(".write"), JOURNAL_ICON, **link)
            snooze(row)
          end
        end

        def lapsing(row)
          href = Helpers::ServiceTab.services(routes, selected: row.record_id)
          sub = row.days.negative? ? t(".lapsed") : t(".lapsing", count: row.days)

          ListItem(title: row.title, href:, sub:, icon: "fa-solid fa-hourglass-end", **hovered(row)) do
            icon_link(href, t(".open_services"), "fa-solid fa-plug")
            snooze(row)
          end
        end

        def move(row)
          list = t(Helpers::TaskLists.title(NEXT))

          task_form(:admin_move_task, row, t(".move", list:), "fa-solid fa-arrow-right", filter: NEXT)
        end

        def new_device(row)
          sub = t(".first_seen", count: row.days)

          ListItem(title: row.title, href: nil, sub:, icon: "fa-solid fa-shield-halved", **hovered(row)) do
            icon_link(path(:admin_security), t(".open_security"), "fa-solid fa-shield-halved")
            snooze(row)
          end
        end

        def post(row, id, sub, icon, reason = nil)
          href = path(:admin_edit_post, id:)

          ListItem(title: row.title, href:, sub:, icon:, **hovered(row)) do |item|
            item.sub { reason } if reason
            icon_link(href, t(".open"), :edit)
            snooze(row)
          end
        end

        def row(row) = send(row.kind, row)

        def snooze(row)
          Form(action: path(:admin_snooze_attention)) do
            HiddenFields(values: identity(row))
            icon_button(t(".snooze"), "fa-solid fa-bell-slash")
          end
        end

        def someday(row) = task(row, t(".untouched", count: row.days), "fa-regular fa-hourglass")

        def task(row, sub, icon)
          href = path(:admin_task, id: row.record_id, origin: ORIGIN)

          ListItem(title: row.title, href:, sub:, icon:, **hovered(row)) do
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
          lines = [@inbox, @failed_social_posts.size, @webmentions, @more_dead_jobs, @broken_links.values.sum]
                  .count(&:positive?)

          @rows.size + @failures.size + @dead_jobs.size + lines
        end
      end
    end
  end
end
