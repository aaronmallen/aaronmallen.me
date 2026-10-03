# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Row < Component
          ARCHIVE = [:admin_archive_project, ".archive", "fa-solid fa-box-archive", :gh].freeze
          ARCHIVED_TAB = Blog::Types::ProjectFilter["archived"]
          EDIT_ICON = "fa-regular fa-pen-to-square"
          RESTORE = [:admin_restore_project, ".restore", "fa-solid fa-rotate-left", nil].freeze
          WRITING = /\S/

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :first, Blog::Types::Bool, default: false
          prop :last, Blog::Types::Bool, default: false

          def view_template
            div(class: "li", data: { key_row: true }) do
              div(class: "li-main") do
                a(class: "li-title mono", href: path(:admin_edit_project, id: @project.id), data: { key_open: true }) do
                  @project.name
                end
                p(class: "proj-tagline") { @project.tagline } if written?(@project.tagline)
                meta
              end
              div(class: "li-side") { side }
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
              Button(type: "submit", variant:, small: true) do
                i(class: icon, aria: { hidden: "true" })
                span { t(label_key) }
              end
            end
          end

          def edit
            a(class: "btn sm", href: path(:admin_edit_project, id: @project.id)) do
              i(class: EDIT_ICON, aria: { hidden: "true" })
              span { t(".edit") }
            end
          end

          def featured
            Pill(color: :orange) do
              i(class: "fa-solid fa-star", aria: { hidden: "true" })
              span { t(".featured") }
            end
          end

          def meta
            p(class: "proj-meta") do
              repo if written?(@project.repo)
              @project.tags.each { |tag| span { tag.name } }
              stars
              span { @project.release } if written?(@project.release)
              archived_on if @project.archived_on
            end
          end

          def repo
            span do
              i(class: "fa-brands fa-github", aria: { hidden: "true" })
              span { @project.repo }
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
              i(class: "fa-regular fa-star", aria: { hidden: "true" })
              span { Blog::Figures.count(@project.stars) }
            end
          end

          def stars_label = t(".stars", count: @project.stars, stars: Blog::Figures.count(@project.stars))

          def written?(value) = value.to_s.match?(WRITING)
        end
      end
    end
  end
end
