# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class GroupForm < Component
          prop :group, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def self.delete_id(group) = "#{scope(group)}-delete"

          def self.form_id(group) = "#{scope(group)}-form"

          def self.remove_id(group, file) = "#{scope(group)}-remove-#{file.id}"

          def self.scope(group) = "share-group-#{group.id}"

          def view_template
            p(class: "file-drawer-name") { t(".name", count: files.size) }
            p(class: "file-drawer-meta") { meta }
            h3(class: "file-drawer-head") { t(".link") }
            code(class: "file-drawer-link") { link }
            div(class: "file-drawer-copy") { copy }
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
              Button(type: "submit", small: true, icon: "fa-solid fa-plus") { t(".add") }
            end
          end

          def alt_text(file)
            input = {
              name: "group[files][#{file.id}][alt_text]", value: alt_text_value(file),
              placeholder: t(".alt_text_placeholder"),
            }

            Field(
              label: t(".alt_text"), name: :alt_text, errors: @errors.dig(:files, file.id) || {}, error: FieldError,
              scope: "#{scope}-file-#{file.id}",
            ) do |control, field|
              Input(**control, **input, autocomplete: "off")
              field.after { Hint { t(".alt_text_hint") } }
            end
          end

          def alt_text_value(file) = @values ? @values[:alt_texts][file.id.to_s] : file.alt_text.to_s

          def code_field
            value = @values ? @values[:code] : @group.code

            Field(label: t(".code"), name: :code, errors: @errors, error: FieldError, scope:) do |control, field|
              Input(**control, name: "group[code]", value:, autocomplete: "off", spellcheck: "false")
              field.after { Hint { t("ui.components.links.link_form.code_hint", host: Helpers::ShareLink.host) } }
            end
          end

          def copy
            Button(
              small: true, variant: :pri, icon: "fa-solid fa-link",
              data: { record_key: link, record_key_copied: t(".link_copied") },
            ) { t(".copy_link") }
          end

          def count(value) = Blog::Helpers::Figures.count(value)

          def delete_form
            Form(
              id: self.class.delete_id(@group), action: path(:admin_delete_file_group, id: @group.id),
              data: { confirm: t(".confirm_delete", count: files.size) },
            )
          end

          def edit_form
            action = path(:admin_update_file_group, id: @group.id)

            Form(id: self.class.form_id(@group), action:, class: "form-stack") do
              code_field
              h3(class: "file-drawer-head") { t(".files") }
              ul(class: "file-group-list") { files.each { item(it) } }
            end
          end

          def files = @group.share_group_files

          def image?(file) = Tile::IMAGE.match?(file.content_type)

          def item(file)
            li(class: "file-group-item") do
              thumb(file)
              div(class: "file-group-item-body") { item_body(file) }
              Button(
                small: true, variant: :gh, type: "submit", form: self.class.remove_id(@group, file),
                icon: "fa-regular fa-trash-can", label: t(".remove", name: file.filename),
              )
            end
          end

          def item_body(file)
            p(class: "file-group-item-name") do
              a(href: "#{link}/#{file.id}", target: "_blank", rel: "noopener") { file.filename }
            end
            p(class: "file-card-meta") do
              span { Blog::Helpers::Figures.size(file.byte_size) }
              span { t(".downloads", count: file.download_count, downloads: count(file.download_count)) }
            end
            alt_text(file) if image?(file)
          end

          def link = Helpers::ShareLink.for(@group.code)

          def meta
            span { Blog::Helpers::Figures.size(files.sum(&:byte_size)) }
            span { t(".uploaded", on: l(Blog::TimeZone.today(@group.created_at), format: :long)) }
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
            end
          end

          def scope = self.class.scope(@group)

          def thumb(file)
            if image?(file)
              img(class: "file-group-thumb", src: "#{link}/#{file.id}?preview", alt: file.alt_text.to_s,
                  loading: "lazy")
            else
              span(class: "file-group-thumb", aria: { hidden: true }) do
                Icon(Tile::ICONS.find { |type, _| type.match?(file.content_type) }&.last || Tile::FILE_ICON)
              end
            end
          end
        end
      end
    end
  end
end
