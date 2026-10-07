# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class Index < View
          include Components::Projects

          ARCHIVED = Blog::Types::ProjectFilter["archived"]
          LIVE = Blog::Types::ProjectFilter["live"]
          WORK = Blog::Types::ProjectFilter["work"]

          CARDS = { LIVE => [".live_label", ".live_title"], ARCHIVED => [".archived_label", ".archived_title"] }.freeze
          EMPTY = { LIVE => ".empty.live", ARCHIVED => ".empty.archived", WORK => ".empty.work" }.freeze
          FILTERS = {
            LIVE => "ui.views.projects.index.live",
            ARCHIVED => "ui.views.projects.index.archived",
            WORK => "ui.views.projects.index.work",
          }.freeze

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
            work? ? work : card
            Hint { t(".archive_note") } if @filter == LIVE
          end

          private

          def archived? = @filter == ARCHIVED

          def card
            label_key, title_key = CARDS.fetch(@filter)

            Card(label: t(label_key), title: t(title_key), data: { key_list: true }) do |card|
              card.side { Hint(inline: true) { t(".archived_hint") } } if archived?
              rows
            end
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

          def rows
            return Empty { t(EMPTY.fetch(@filter)) } if @projects.empty?

            @projects.each { Row(project: it, filter: @filter) }
          end

          def sub
            dotted(
              t(".live_count", count: @live_count),
              t(".archived_count", count: @archived_count),
              t(".stars_count", count: @stars, stars: Blog::Figures.count(@stars)),
            )
          end

          def work
            Grid(columns: 2) do
              Card(label: t(".work_label"), title: t(".work_title"), data: { key_list: true }) { work_rows }
              SideStack do
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
