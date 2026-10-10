# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class Palette < Component
          ACTIONS_GROUP = "command-palette-group-actions"
          CREATE_TASK_ID = "command-palette-create-task-typed"
          DIALOG_ID = "command-palette"
          HINTS = { ".move" => "↑↓", ".open" => "↵", ".anywhere" => "⌘K" }.freeze
          LIST_ID = "command-palette-list"
          QUERY = "{query}"
          SEE_ALL_GROUP = "command-palette-group-see-all"
          SEE_ALL_ID = "command-palette-see-all"
          TASK_TITLE = "task[title]"
          TITLE = "{title}"

          prop :actions, Blog::Types::Array.of(Blog::Types::Instance(Structs::Action))
          prop :sections, Blog::Types::Array.of(Blog::Types::Instance(Structs::Section))

          def view_template
            dialog(
              id: DIALOG_ID, class: "pal-b", aria: { label: t(".label") },
              data: {
                dialog: true, palette: true, palette_search: path(:admin_palette_search), palette_token: csrf_token,
              },
            ) do
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
            return if @actions.empty?

            row_group(ACTIONS_GROUP, t(".actions")) do
              @actions.each { action_row(it) }
            end
          end

          def action_row(action)
            return action_rows(action) if action.from

            label = t(action.label_key)

            PaletteRow(
              id: action.id, icon: action.icon, label:, text: "#{label}, #{t(action.text_key)}".downcase,
              href: action.path, needs: action.needs&.to_s, **action.to_h.slice(:dialog, :post, :key, :click),
            )
          end

          def action_rows(action)
            label = t(action.label_key, title: TITLE)

            template(data: { palette_from: action.from }) do
              PaletteRow(
                id: action.id, icon: action.icon, label:, text: "#{label}, #{t(action.text_key)}".downcase,
                post: action.post, needs: action.needs&.to_s,
              )
            end
          end

          def category_groups
            @sections.group_by(&:group).each do |group, sections|
              row_group("command-palette-group-#{group}", t(sections.first.group_key)) do
                sections.each { section_row(it) }
              end
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
              Icon("fa-solid fa-magnifying-glass pal-in-icon")
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
              action_group
              PaletteRecords()
              PaletteSavedViews()
              category_groups
              search_group
            end
          end

          def row_group(id, heading, data: Blog::Constants::EMPTY_HASH, &)
            PaletteGroup(id:, heading:, data:, &)
          end

          def search_group
            search = path(:admin_search)

            row_group(SEE_ALL_GROUP, t(".search")) do
              PaletteRow(
                id: SEE_ALL_ID, icon: "fa-magnifying-glass", label: t(".see_all", query: QUERY), href: search,
                all: search, query: true,
              )
              PaletteRow(
                id: CREATE_TASK_ID, icon: "fa-plus", label: t(".create_task", query: QUERY),
                href: path(:admin_new_task), dialog: Tasks::CreateDialog::ID, fill: TASK_TITLE, query: true,
              )
            end
          end

          def section_row(section)
            label = t(section.label_key)

            PaletteRow(
              id: "command-palette-#{section.name}", icon: section.icon, label:, href: section.path,
              text: "#{label} #{t(section.group_key)}".downcase, sub: section_sub(section), warn: section.waiting?,
              jump: section.jump,
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
        end
      end
    end
  end
end
