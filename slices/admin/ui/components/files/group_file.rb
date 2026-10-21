# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class GroupFile < Component
          prop :group, Blog::Types::Instance(ROM::Struct)
          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            li(class: "file-group-item") do
              thumb
              div(class: "file-group-item-body") { body }
              Button(
                small: true, variant: :gh, type: "submit", form: GroupForm.ungroup_id(@group, @file),
                icon: "fa-solid fa-arrow-right-from-bracket", label: t(".ungroup", name: @file.filename),
              )
              Button(
                small: true, variant: :gh, type: "submit", form: GroupForm.remove_id(@group, @file),
                icon: :trash, label: t(".remove", name: @file.filename),
              )
            end
          end

          private

          def body
            p(class: "file-group-item-name") do
              a(href: link, target: "_blank", rel: "noopener") { @file.filename }
            end
            p(class: "file-card-meta") { meta }
            field(:filename, t(".filename"), t(".filename_hint"), spellcheck: "false")
            return unless image?

            field(:alt_text, t(".alt_text"), t(".alt_text_hint"), placeholder: t(".alt_text_placeholder"))
          end

          def field(name, label, hint, **)
            Field(
              label:, name:, errors: @errors.dig(:files, @file.id) || {}, error: FieldError,
              scope: "#{GroupForm.scope(@group)}-file-#{@file.id}",
            ) do |control, field|
              Input(**control, name: "group[files][#{@file.id}][#{name}]", value: value(name), autocomplete: "off", **)
              field.after { Hint { hint } }
            end
          end

          def image? = Shares::ContentType.image?(@file.content_type)

          def link = Helpers::ShareLink.for(@group.code, @file.id)

          def meta
            downloads = Blog::Helpers::Figures.count(@file.download_count)

            span { Blog::Helpers::Figures.size(@file.byte_size) }
            span { t(".downloads", count: @file.download_count, downloads:) }
          end

          def thumb
            if image?
              img(class: "file-group-thumb", src: "#{link}?preview", alt: @file.alt_text.to_s, loading: "lazy")
            else
              span(class: "file-group-thumb", aria: { hidden: true }) do
                Icon(Tile::ICONS.find { |type, _| type.match?(@file.content_type) }&.last || Tile::FILE_ICON)
              end
            end
          end

          def value(name) = @values ? @values.dig(:files, @file.id.to_s, name).to_s : @file.public_send(name).to_s
        end
      end
    end
  end
end
