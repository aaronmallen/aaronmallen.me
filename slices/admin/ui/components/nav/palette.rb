# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class Palette < Component
          ACTIONS_GROUP = "command-palette-group-actions"
          DIALOG_ID = "command-palette"
          HINTS = { ".move" => "↑↓", ".open" => "↵", ".anywhere" => "⌘/" }.freeze
          LIST_ID = "command-palette-list"
          LISTS = {
            Blog::Types::TaskView["external"] => ".lists.external",
            Blog::Types::TaskView["next"] => ".lists.next",
            Blog::Types::TaskView["someday"] => ".lists.someday",
            Blog::Types::TaskView["today"] => ".lists.today",
            Blog::Types::TaskView["upcoming"] => ".lists.upcoming",
          }.freeze
          TASKS_GROUP = "command-palette-group-tasks"

          prop :sections, Blog::Types::Array.of(Blog::Types::Instance(Structs::Section))
          prop(
            :tasks,
            Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))),
          )

          def view_template
            dialog(id: DIALOG_ID, class: "pal-b", aria: { label: t(".label") }, data: { palette: true }) do
              div(class: "pal") do
                query_box
                results
                status
                footer
              end
            end
          end

          private

          def action_group
            row_group(ACTIONS_GROUP, t(".actions")) do
              PaletteRow(
                id: "command-palette-create-task", icon: "fa-plus", label: t(".create_task"),
                text: t(".create_task_text"), href: path(:admin_new_task), dialog: Tasks::CreateDialog::ID,
              )
              PaletteRow(
                id: "command-palette-create-journal-entry", icon: "fa-pen", label: t(".create_journal_entry"),
                text: t(".create_journal_entry_text"), href: path(:admin_journal, write: Blog::Constants::CHECKED),
              )
            end
          end

          def footer
            div(class: "pal-f", aria: { hidden: "true" }) do
              HINTS.each do |key, keys|
                span do
                  span(class: "kbd") { keys }
                  whitespace
                  plain(t(key))
                end
              end
            end
          end

          def query_box
            div(class: "pal-in") do
              i(class: "fa-solid fa-magnifying-glass pal-in-icon", aria: { hidden: "true" })
              input(
                type: "text", class: "pal-in-field", role: "combobox", autocomplete: "off",
                placeholder: t(".placeholder"), data: { palette_query: true },
                aria: { autocomplete: "list", controls: LIST_ID, expanded: "true", label: t(".query_label") },
              )
              span(class: "kbd", aria: { hidden: "true" }) { t(".escape") }
            end
          end

          def results
            div(
              id: LIST_ID, class: "pal-l", role: "listbox",
              aria: { label: t(".results_label") }, data: { palette_list: true },
            ) do
              @sections.group_by(&:group).each_value do |sections|
                row_group("command-palette-group-#{sections.first.group}", t(sections.first.group_key)) do
                  sections.each { section_row(it) }
                end
              end
              action_group
              task_group
            end
          end

          def row_group(id, heading, &)
            div(class: "pal-grp", role: "group", aria: { labelledby: id }, data: { palette_group: true }) do
              p(id:, class: "pal-g") { heading }
              yield
            end
          end

          def section_row(section)
            label = t(section.label_key)

            PaletteRow(
              id: "command-palette-#{section.name}", icon: section.icon, label:, href: section.path,
              text: "#{label} #{t(section.group_key)}".downcase, sub: section_sub(section), warn: section.waiting?,
            )
          end

          def section_sub(section)
            return t(".waiting", count: section.count) if section.waiting?

            t(".current") if section.current
          end

          def status
            p(
              class: "sr-only", role: "status",
              data: {
                palette_status: true, palette_results_one: t(".results.one"),
                palette_results_other: t(".results.other"),
              },
            )
          end

          def task_group
            return if @tasks.values.all?(&:empty?)

            row_group(TASKS_GROUP, t(".tasks")) do
              @tasks.each { |filter, tasks| tasks.each { task_row(it, filter) } }
            end
          end

          def task_row(task, filter)
            PaletteRow(
              id: "command-palette-task-#{task.id}", icon: "fa-list-check", label: task.title,
              text: task.title.downcase, href: path(:admin_tasks, filter:),
              sub: t(".in_list", list: t(LISTS.fetch(filter))), task: true, hidden: true,
            )
          end
        end
      end
    end
  end
end
