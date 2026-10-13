# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Menu < View
          include Components::Tasks

          CHECK = Components::ContextMenu::CHECK
          EDIT = Components::Tasks::Row::EDIT
          EXTERNAL = Blog::Types::TaskFilter["external"]
          FROM_INBOX = Blog::Types::TaskOrigin["inbox"]
          ISSUE = "fa-solid fa-arrow-up-right-from-square"
          TAG = Blog::Types::TaskBulkAction["tag"]
          UNTAG = Blog::Types::TaskBulkAction["untag"]

          layout nil

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :today, Blog::Types::Date
          prop :sprints, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :return_to, Blog::Types::String.optional
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::TaskOrigin
          prop :board, Blog::Types::Integer.optional, default: nil

          def view_template
            ContextMenu(label: "#{key} · #{@task.title}", return_to: @return_to) do |menu|
              menu.link(t(".open"), href: open_path, icon: "fa-regular fa-pen-to-square", key: EDIT)
              menu.separator
              progress(menu)
              column(menu) if @board
              MenuPlan(menu:, task: @task, today: @today, sprints: @sprints) unless closed?
              records(menu)
              menu.separator
              ends(menu)
            end
          end

          private

          def act(route, **) = path(route, id: @task.id, **)

          def closed? = @task.closed?

          def column(menu)
            menu.sub(t(".column"), icon: "fa-solid fa-table-columns") do
              Blog::Types::TaskColumn.each_value do |name|
                here = @task.board_column == name
                label = t(Components::Projects::BoardCard::NAMES.fetch(name))
                action = path(:admin_move_project_task, id: @board, task_id: @task.id)

                menu.post(label, action:, fields: { to: name }, icon: (CHECK if here), disabled: here)
              end
            end
          end

          def copies(menu)
            menu.sub(t(".copy"), icon: "fa-regular fa-copy") do
              copied = t("ui.components.record_key.copied.task", key:)
              menu.copy(t(".copy_number"), text: key, copied:, icon: nil, hint: key)
              menu.copy(t(".copy_title"), text: @task.title, copied: t(".copied_title"), icon: nil)
              source { menu.copy(t(".copy_issue"), text: it.url, copied: t(".copied_issue"), icon: nil) }
            end
          end

          def ends(menu)
            menu.post(t(".cancel"), action: act(:admin_cancel_task), icon: "fa-solid fa-ban") unless closed?
            confirm = t(".confirm_delete")
            menu.post(t(".delete"), action: act(:admin_delete_task), icon: "fa-regular fa-trash-can", warn: true,
                                    confirm:)
          end

          def key = Components::RecordKey.key(@task.id)

          def open_path = act(:admin_task, filter: @filter, origin: @origin)

          def progress(menu)
            if closed?
              menu.post(t(".reopen"), action: act(:admin_reopen_task), icon: "fa-solid fa-rotate-left")
            else
              start_or_pause(menu)
              menu.post(t(".complete"), action: act(:admin_complete_task), icon: "fa-solid fa-check")
            end
          end

          def records(menu)
            tags(menu)
            copies(menu)
            source { menu.link(t(".open_issue"), href: it.url, icon: ISSUE, outbound: true) }
            seen(menu)
            Components::Inbox::SnoozeMenu(menu:, kind: "task", id: @task.id) if @origin == FROM_INBOX
          end

          def running? = @task.in_progress? && @task.in_sprint?

          def seen(menu)
            source = @task.source
            return unless @task.list == EXTERNAL && source && source.seen_at.nil?

            menu.post(t(".mark_seen"), action: act(:admin_inbox_see_task), icon: "fa-solid fa-check-double")
          end

          def short(date) = l(date, format: :short)

          def source
            yield @task.source if @task.source
          end

          def start_or_pause(menu)
            if running?
              menu.post(t(".pause"), action: act(:admin_stop_task), icon: "fa-solid fa-pause")
            else
              menu.post(t(".start"), action: act(:admin_start_task), icon: "fa-solid fa-play")
            end
          end

          def tags(menu)
            names = @task.tags.map(&:name)
            invalid = t("tasks_page.toasts.bulk.invalid.tag_format")

            menu.tags(t(".tags"), names:, tags: @tags, new_tag: t(".new_tag"), invalid:) do |name, on|
              tag = name ? { tag: name } : Blog::Constants::EMPTY_HASH

              { action: path(:admin_bulk_tasks), fields: { act: on ? UNTAG : TAG, "ids[]": @task.id, **tag } }
            end
          end
        end
      end
    end
  end
end
