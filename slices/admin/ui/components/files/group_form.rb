# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class GroupForm < Component
          prop :group, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          extend ShareIds

          SCOPE = "share-group"

          def self.remove_id(group, file) = "#{scope(group)}-remove-#{file.id}"

          def self.ungroup_id(group, file) = "#{scope(group)}-ungroup-#{file.id}"

          def view_template
            ShareSummary(kind: :group, name: title, link:) { it.meta { meta } }
            edit_form
            add_form
            remove_forms
            delete_form
          end

          private

          def add_form
            Form(action: path(:admin_create_files), enctype: "multipart/form-data", class: "file-group-add") do
              input(type: "hidden", name: "group_id", value: @group.id)
              label(class: "f", for: "#{scope}-add") { t(".add_label") }
              input(id: "#{scope}-add", class: "file-drop-input", type: "file", name: "files[]", multiple: true)
              Button(type: "submit", small: true, icon: :add) { t(".add") }
            end
          end

          def code_hint = t("ui.components.links.link_form.code_hint", host: Helpers::ShareLink.host)

          def delete_form
            Form(
              id: self.class.delete_id(@group), action: path(:admin_delete_file_group, id: @group.id),
              data: { confirm: t(".confirm_delete", count: files.size) },
            )
          end

          def edit_form
            action = path(:admin_update_file_group, id: @group.id)

            Form(id: self.class.form_id(@group), action:, class: "form-stack") do
              group_field(:name, t(".group_name"), t(".group_name_hint"), placeholder: @group.code)
              group_field(:code, t(".code"), code_hint, spellcheck: "false")
              h3(class: "file-drawer-head") { t(".files") }
              ul(class: "file-group-list") { file_items }
            end
          end

          def file_items
            files.each { render GroupFile.new(group: @group, file: it, values: @values, errors: @errors) }
          end

          def files = @group.share_group_files

          def group_field(name, label, hint, **)
            value = @values ? @values[name] : @group.public_send(name).to_s

            Field(label:, name:, errors: @errors, error: FieldError, scope:) do |control, field|
              Input(**control, name: "group[#{name}]", value:, autocomplete: "off", **)
              field.after { Hint { hint } }
            end
          end

          def link = Helpers::ShareLink.for(@group.short)

          def meta
            span { Blog::Helpers::Figures.size(files.sum(&:byte_size)) }
            span { t(".uploaded", on: l(Blog::TimeZone.local_date(@group.created_at), format: :long)) }
            span { t(".views", count: @group.view_count, views: count(@group.view_count)) }
            span { t(".zips", count: @group.zip_download_count, zips: count(@group.zip_download_count)) }
          end

          def remove_forms
            files.each do |file|
              Form(
                id: self.class.remove_id(@group, file),
                action: path(:admin_remove_file_group_file, id: @group.id, file_id: file.id),
                data: { confirm: t(".confirm_remove", name: file.filename) },
              )
              Form(
                id: self.class.ungroup_id(@group, file),
                action: path(:admin_ungroup_file_group_file, id: @group.id, file_id: file.id),
                data: { confirm: t(".confirm_ungroup", name: file.filename) },
              )
            end
          end

          def scope = self.class.scope(@group)

          def title = @group.name || t(".name", count: files.size)
        end
      end
    end
  end
end
