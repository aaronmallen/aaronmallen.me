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
          SEPARATOR = " · "

          def initialize(
            archived_count:, featured_count:, filter:, live_count:, projects:, stars:,
            work_entries:, work_errors:, work_links:, work_values:
          )
            super()
            @archived_count = archived_count
            @featured_count = featured_count
            @filter = filter
            @live_count = live_count
            @projects = projects
            @stars = stars
            @work_entries = work_entries
            @work_form = { values: work_values, errors: work_errors }
            @work_links = work_links
          end

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

            last = @projects.size - 1
            @projects.each_with_index do |project, index|
              Row(project:, filter: @filter, first: index.zero?, last: index == last)
            end
          end

          def sub
            [
              t(".live_count", count: @live_count),
              t(".featured_count", count: @featured_count),
              t(".archived_count", count: @archived_count),
              t(".stars_count", count: @stars, stars: Blog::Figures.count(@stars)),
            ].join(SEPARATOR)
          end

          def work
            Grid(columns: 2) do
              Card(label: t(".work_label"), title: t(".work_title"), data: { key_list: true }) { work_rows }
              SideStack do
                work_linked if @work_links
                Components::WorkEntries::EntryForm(**@work_form)
              end
            end
          end

          def work? = @filter == WORK

          def work_linked
            entry = @work_links[:entry]
            id = entry.id

            RecordLinks::Section(
              records: @work_links[:records], scope: "work-entry-#{id}-record", id:, fields: { filter: WORK, edit: id },
              label: t(".work_linked", org: entry.org, role: entry.role), unlink_route: :admin_unlink_work_entry_record,
              link_path: path(:admin_link_work_entry_record, id:), find_path: path(:admin_projects),
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
