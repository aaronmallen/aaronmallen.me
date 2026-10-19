# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class ShareForm < Component
          prop :share, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          extend ShareIds

          SCOPE = "share"

          def view_template
            preview
            ShareSummary(kind: :file, name: @share.filename, link:, markdown:) { it.meta { meta } }
            edit_form
            delete_form
          end

          private

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

          def image? = Shares::ContentType.image?(@share.content_type)

          def link = Helpers::ShareLink.for(@share.short)

          def markdown = Helpers::ShareLink.file_markdown(@share, link)

          def meta
            span { Blog::Helpers::Figures.size(@share.byte_size) }
            span { @share.content_type }
            span { t(".uploaded", on: l(Blog::TimeZone.local_date(@share.created_at), format: :long)) }
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

          def thumb = Helpers::ShareLink.preview(@share.short)

          def values = @values || { filename: @share.filename, code: @share.code, alt_text: @share.alt_text.to_s }
        end
      end
    end
  end
end
