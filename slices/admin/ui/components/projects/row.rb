# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Row < Component
          ARCHIVE = [:admin_archive_project, ".archive", "fa-solid fa-box-archive", :gh].freeze
          EDIT_ICON = "fa-regular fa-pen-to-square"
          PRIVATE = Blog::Types::ProjectVisibility["private"]
          RESTORE = [:admin_restore_project, ".restore", "fa-solid fa-rotate-left", nil].freeze

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String

          def view_template
            section(class: "card project-card", data: { key_row: true }) do
              div(class: "project-card-head") do
                a(class: "project-card-name", href: edit_path, data: { key_open: true }) { @project.name }
                pills
                div(class: "project-card-acts hov") { acts }
              end
              p(class: "project-card-tagline") { @project.tagline } if written?(@project.tagline)
              p(class: "project-card-meta") { meta }
            end
          end

          private

          def acts
            change(*(@project.archived? ? RESTORE : ARCHIVE))
            label = t(".edit")

            Button(href: edit_path, small: true, title: label, icon: EDIT_ICON) { span(class: "sr-only") { label } }
          end

          def archived_on
            span { t(".archived_on", date: l(@project.archived_on, format: :medium)) }
          end

          def change(route, label_key, icon, variant)
            Form(action: path(route, id: @project.id)) do
              input(type: "hidden", name: "filter", value: @filter)
              Button(type: "submit", variant:, small: true, title: t(label_key), icon:) do
                span(class: "sr-only") { t(label_key) }
              end
            end
          end

          def edit_path = path(:admin_edit_project, id: @project.id)

          def hidden
            Pill(color: :sand, icon: "fa-solid fa-lock") { t(".private") }
          end

          def meta
            repo if written?(@project.repo)
            @project.tags.each { Tag(tag: it) }
            stars
            span { @project.release } if written?(@project.release)
            archived_on if @project.archived_on
          end

          def pills
            hidden if @project.visibility == PRIVATE
            Projects::StatusPill(archived: @project.archived?)
          end

          def repo
            span do
              IconLabel(icon: "fa-brands fa-github") { @project.repo }
            end
          end

          def stars
            span(role: "img", aria: { label: stars_label }) do
              IconLabel(icon: "fa-regular fa-star") { Blog::Helpers::Figures.count(@project.stars) }
            end
          end

          def stars_label = t(".stars", count: @project.stars, stars: Blog::Helpers::Figures.count(@project.stars))
        end
      end
    end
  end
end
