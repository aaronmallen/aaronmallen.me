# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Editor < Component
          SEPARATOR = " · "
          WRITING = /\S/

          prop :project, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :featured, Blog::Types::Bool

          def view_template
            BackLink(href: path(:admin_projects), variant: :gh, small: true, class: "editor-back") do
              t(".all_projects")
            end

            StatusForm(project: @project) if @project

            Form(action: form_action, data: { project_editor: "" }) do
              page_head
              columns
            end
          end

          private

          def archived? = @project&.archived? || false

          def columns
            div(class: "editor") do
              SideStack do
                PublicCopy(values: @values, errors: @errors)
                Preview(values: @values, release:, stars:)
              end
              SideStack do
                Repository(values: @values, errors: @errors, release:, stars:)
                Placement(values: @values, errors: @errors, archived: archived?, featured: @featured)
              end
            end
          end

          def form_action = @project ? path(:admin_update_project, id: @project.id) : path(:admin_create_project)

          def name_attributes
            {
              **FieldError.control_attributes(:name, @errors),
              class: "editor-title mono",
              type: "text",
              name: "project[name]",
              value: @values[:name],
              placeholder: t(".name_placeholder"),
              data: { editor_name: "" },
            }
          end

          def name_block
            div(class: "editor-head") do
              label(class: "sr-only", for: FieldError.id_for(:name)) { t(".name") }
              input(**name_attributes)
              FieldError(field: :name, errors: @errors)
              sub_line
            end
          end

          def named? = @values[:name].match?(WRITING)

          def page_head
            header(class: "page-head") do
              name_block
              EditorActions(archived: archived?, existing: !@project.nil?, named: named?)
            end
          end

          def release = @project&.release

          def stars = @project&.stars || 0

          def sub_line
            p(class: "page-head-sub") do
              span(data: { editor_repo: t(".repo_placeholder") }) { text(:repo, ".repo_placeholder") }
              sub_release
            end
          end

          def sub_release
            return unless release.to_s.match?(WRITING)

            plain SEPARATOR
            span { release }
          end

          def text(field, placeholder_key)
            value = @values[field]

            value.match?(WRITING) ? value : t(placeholder_key)
          end
        end
      end
    end
  end
end
