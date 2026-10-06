# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Row < Component
          ARCHIVE = [:admin_archive_project, ".archive", "fa-solid fa-box-archive", :gh].freeze
          ARCHIVED_TAB = Blog::Types::ProjectFilter["archived"]
          EDIT_ICON = "fa-regular fa-pen-to-square"
          MONO = { class: "mono" }.freeze
          RESTORE = [:admin_restore_project, ".restore", "fa-solid fa-rotate-left", nil].freeze

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :first, Blog::Types::Bool, default: false
          prop :last, Blog::Types::Bool, default: false

          def view_template
            ListItem(title: @project.name, href: path(:admin_edit_project, id: @project.id), link: MONO) do |item|
              item.body { p(class: "proj-tagline") { @project.tagline } } if written?(@project.tagline)
              item.meta { meta }
              side
            end
          end

          private

          def archived_on
            span { t(".archived_on", date: l(@project.archived_on, format: :medium)) }
          end

          def archived_tab? = @filter == ARCHIVED_TAB

          def change(route, label_key, icon, variant)
            Form(action: path(route, id: @project.id)) do
              input(type: "hidden", name: "filter", value: @filter)
              Button(type: "submit", variant:, small: true, icon:) { t(label_key) }
            end
          end

          def edit
            Button(href: path(:admin_edit_project, id: @project.id), small: true, icon: EDIT_ICON) { t(".edit") }
          end

          def featured
            Pill(color: :orange, icon: "fa-solid fa-star") { t(".featured") }
          end

          def meta
            p(class: "proj-meta") do
              repo if written?(@project.repo)
              @project.tags.each { Tag(tag: it) }
              stars
              span { @project.release } if written?(@project.release)
              archived_on if @project.archived_on
            end
          end

          def repo
            span do
              IconLabel(icon: "fa-brands fa-github") { @project.repo }
            end
          end

          def side
            Move(project: @project, first: @first, last: @last) unless archived_tab?
            featured if @project.featured
            Projects::StatusPill(status: @project.status)
            change(*(@project.archived? ? RESTORE : ARCHIVE))
            edit
          end

          def stars
            span(role: "img", aria: { label: stars_label }) do
              IconLabel(icon: "fa-regular fa-star") { Blog::Figures.count(@project.stars) }
            end
          end

          def stars_label = t(".stars", count: @project.stars, stars: Blog::Figures.count(@project.stars))
        end
      end
    end
  end
end
