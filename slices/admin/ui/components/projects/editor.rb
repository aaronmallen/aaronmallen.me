# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Editor < Component
          prop :project, Blog::Types::Instance(ROM::Struct).optional
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash

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
                Placement(values: @values, errors: @errors, archived: archived?)
              end
            end
          end

          def form_action = @project ? path(:admin_update_project, id: @project.id) : path(:admin_create_project)

          def name_attributes
            {
              class: "mono",
              name: "project[name]",
              value: @values[:name],
              placeholder: t(".name_placeholder"),
              data: { editor_name: "" },
            }
          end

          def named? = written?(@values[:name])

          def page_head
            EditorHead(label: t(".name"), field: :name, errors: @errors, error: FieldError, **name_attributes) do |head|
              head.sub { sub_line }
              EditorActions(archived: archived?, existing: !@project.nil?, named: named?)
            end
          end

          def release = @project&.release

          def stars = @project&.stars || 0

          def sub_line
            span(data: { editor_repo: t(".repo_placeholder") }) { text(:repo, ".repo_placeholder") }
            sub_release
          end

          def sub_release
            return unless written?(release)

            plain DOT
            span { release }
          end

          def text(field, placeholder_key)
            value = @values[field]

            written?(value) ? value : t(placeholder_key)
          end
        end
      end
    end
  end
end
