# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class TagManager < Component
          ID = "project-tags"

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :usage, Blog::Types::Hash
          prop :open, Blog::Types::Bool, default: false

          def view_template
            button
            Dialog(id: ID, title: t(".title", name: @project.name), data: { dialog_show: (true if @open) }) do |dialog|
              dialog.foot { foot }
              capture
              @tags.empty? ? Empty { t(".empty") } : div(class: "project-tags-list") { @tags.each { row(it) } }
            end
          end

          private

          def button
            Button(icon: "fa-solid fa-tag", command: "show-modal", commandfor: ID, **Dialog.opens(ID)) do
              plain t(".tags")
              span(class: "project-tags-count") { @tags.size.to_s }
            end
          end

          def capture
            Form(action: path(:admin_create_project_tag, id: @project.id), class: "project-tags-new") do
              label(class: "sr-only", for: "#{ID}-name") { t(".name") }
              Input(id: "#{ID}-name", name: "tag[name]", autocomplete: "off", placeholder: t(".placeholder"))
              label(class: "sr-only", for: "#{ID}-description") { t(".description") }
              Textarea(
                id: "#{ID}-description", name: "tag[description]", rows: 2, value: nil,
                placeholder: t(".description_placeholder"),
              )
              Button(variant: :pri, small: true, type: "submit", icon: :add) { t(".add") }
            end
          end

          def editor(tag)
            details(class: "project-tags-edit") do
              summary(class: "bt sm gh", aria: { label: t(".edit", tag: tag.name) }) { Icon(:edit) }
              Form(action: path(:admin_update_project_tag, id: @project.id, tag_id: tag.id), class: "field") do
                fields(tag, "#{ID}-#{tag.id}")
                Button(variant: :pri, small: true, type: "submit", icon: :save) { t(".save") }
              end
            end
          end

          def fields(tag, id)
            label(class: "f", for: "#{id}-name") { t(".name") }
            Input(id: "#{id}-name", name: "tag[name]", value: tag.name, autocomplete: "off")
            label(class: "f", for: "#{id}-description") { t(".description") }
            Textarea(id: "#{id}-description", name: "tag[description]", rows: 2, value: tag.description)
            span(class: "f") { t(".color") }
            Swatches(name: "tag[color]", scope: id, selected: tag.color)
          end

          def foot
            Hint { t(".count", count: @tags.size) }
            Button(variant: :pri, small: true, data: { dialog_close: true }) { t(".done") }
          end

          def remove(tag)
            DeleteForm(
              action: path(:admin_delete_project_tag, id: @project.id, tag_id: tag.id), label: t(".remove"),
              icon_only: true, confirm: t(".confirm_remove", tag: tag.name, count: uses(tag)),
            )
          end

          def row(tag)
            div(class: "project-tags-row") do
              summary_of(tag)
              editor(tag)
              remove(tag)
            end
          end

          def summary_of(tag)
            div(class: "project-tags-body") do
              p(class: "project-tags-name") do
                Tag(tag:, project_key: @project.key)
                span(class: "meta") { t(".uses", count: uses(tag)) }
              end
              p(class: ["project-tags-description", ("dim" unless tag.description)]) do
                tag.description || t(".no_description")
              end
            end
          end

          def uses(tag) = @usage.fetch(tag.id, Blog::Constants::EMPTY_HASH).values.sum
        end
      end
    end
  end
end
