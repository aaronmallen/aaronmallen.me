# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class ShareForm < Component
          prop :share, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def self.delete_id(share) = "#{scope(share)}-delete"

          def self.form_id(share) = "#{scope(share)}-form"

          def self.scope(share) = "share-#{share.id}"

          def view_template
            preview
            p(class: "file-drawer-name") { @share.filename }
            p(class: "file-drawer-meta") { meta }
            h3(class: "file-drawer-head") { t(".link") }
            code(class: "file-drawer-link") { link }
            div(class: "file-drawer-copy") { copy }
            edit_form
            delete_form
          end

          private

          def copy
            Button(
              small: true, variant: :pri, icon: "fa-solid fa-link",
              data: { record_key: link, record_key_copied: t(".link_copied") },
            ) { t(".copy_link") }
            return unless image?

            Button(
              small: true, icon: "fa-brands fa-markdown",
              data: {
                record_key: "!#{Helpers::ShareLink.markdown(@share.alt_text, link)}",
                record_key_copied: t(".markdown_copied"),
              },
            ) { t(".copy_markdown") }
          end

          def delete_form
            Form(
              id: self.class.delete_id(@share), action: path(:admin_delete_file, id: @share.id),
              data: { confirm: t(".confirm_delete", name: @share.filename) },
            )
          end

          def downloads = Blog::Helpers::Figures.count(@share.download_count)

          def edit_form
            action = path(:admin_update_file, id: @share.id)

            Form(id: self.class.form_id(@share), action:, class: "form-stack") { fields }
          end

          def field(name, label, hint, **)
            Field(label:, name:, errors: @errors, error: FieldError, scope:) do |control, field|
              Input(**control, name: "share[#{name}]", value: values[name], autocomplete: "off", **)
              field.after { Hint { hint } }
            end
          end

          def fields
            code_hint = t("ui.components.links.link_form.code_hint", host: Helpers::ShareLink.host)
            field(:filename, t(".filename"), t(".filename_hint"), spellcheck: "false")
            field(:code, t(".code"), code_hint, spellcheck: "false")
            return unless image?

            field(:alt_text, t(".alt_text"), t(".alt_text_hint"), placeholder: t(".alt_text_placeholder"))
          end

          def image? = Tile::IMAGE.match?(@share.content_type)

          def link = Helpers::ShareLink.for(@share.code)

          def meta
            span { Blog::Helpers::Figures.size(@share.byte_size) }
            span { @share.content_type }
            span { t(".uploaded", on: l(Blog::TimeZone.today(@share.created_at), format: :long)) }
            span { t(".downloads", count: @share.download_count, downloads:) }
          end

          def preview
            return img(class: "file-drawer-preview", src: thumb, alt: @share.alt_text.to_s, loading: "lazy") if image?

            span(class: "file-drawer-preview", aria: { hidden: true }) do
              Icon(Tile::ICONS.find { |type, _| type.match?(@share.content_type) }&.last || Tile::FILE_ICON)
              span { File.extname(@share.filename).delete_prefix(".").upcase }
            end
          end

          def scope = self.class.scope(@share)

          def thumb = Helpers::ShareLink.preview(@share.code)

          def values = @values || { filename: @share.filename, code: @share.code, alt_text: @share.alt_text.to_s }
        end
      end
    end
  end
end
