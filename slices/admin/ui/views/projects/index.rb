# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class Index < View
          include Components::Projects

          LIVE = Blog::Types::ProjectFilter["live"]
          WORK = Blog::Types::ProjectFilter["work"]

          EMPTY = Blog::Types::ProjectFilter.values.to_h { [it, ".empty.#{it}"] }.freeze
          FILTERS = Blog::Types::ProjectFilter.values.to_h { [it, "ui.views.projects.index.#{it}"] }.freeze

          prop :archived_count, Blog::Types::Integer
          prop :filter, Blog::Types::ProjectFilter
          prop :live_count, Blog::Types::Integer
          prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :stars, Blog::Types::Integer
          prop :work_entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :work_errors, Blog::Types::Hash
          prop :work_links, Blog::Types::Hash.optional
          prop :work_values, Blog::Types::Hash

          def view_template
            PageHead(title: t(".heading"), sub:) do
              filter_form
              CreateLink(href: path(:admin_new_project), label: t(".new_project"))
            end
            work? ? work : cards
            Hint { t(".archive_note") } if @filter == LIVE
          end

          private

          def cards
            return Empty { t(EMPTY.fetch(@filter)) } if @projects.empty?

            div(class: "cols", data: { key_list: true }) { @projects.each { Row(project: it, filter: @filter) } }
          end

          def filter_form
            FilterSwitch(
              action: path(:admin_projects),
              name: "filter",
              options: FILTERS,
              selected: @filter,
              label: t(".filter"),
            )
          end

          def sub
            dotted(
              t(".live_count", count: @live_count),
              t(".archived_count", count: @archived_count),
              t(".stars_count", count: @stars, stars: Blog::Helpers::Figures.count(@stars)),
            )
          end

          def work
            div(class: "g-main") do
              Card(title: t(".work_title"), data: { key_list: true }) { work_rows }
              aside(class: "project-side") do
                work_linked if @work_links
                Components::WorkEntries::EntryForm(values: @work_values, errors: @work_errors)
              end
            end
          end

          def work? = @filter == WORK

          def work_linked
            entry = @work_links[:entry]
            id = entry.id

            RecordLinks::Section(
              records: @work_links[:records], kind: "work_entry", id:, fields: { filter: WORK, edit: id },
              label: t(".work_linked", org: entry.org, role: entry.role), find_path: path(:admin_projects),
            )
          end

          def work_linking?(entry) = @work_links&.fetch(:entry)&.id == entry.id

          def work_rows
            return Empty { t(EMPTY.fetch(WORK)) } if @work_entries.empty?

            @work_entries.each { Components::WorkEntries::Row(entry: it, linking: work_linking?(it)) }
          end
        end
      end
    end
  end
end
