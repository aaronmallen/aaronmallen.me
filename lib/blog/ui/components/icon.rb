# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Icon < Component
        ACTIONS = {
          ban: "fa-solid fa-ban",
          close: "fa-solid fa-xmark",
          copy: "fa-regular fa-copy",
          edit: "fa-regular fa-pen-to-square",
          outbound: "fa-solid fa-arrow-up-right-from-square",
          trash: "fa-regular fa-trash-can",
        }.freeze
        INLINE = :inline_icons
        STYLES = %w[fa-brands fa-regular fa-solid].freeze
        SVGS = Dir[File.expand_path("../icons/*/*.svg", __dir__)].to_h do |file|
          [file.split("/").last(2).join("/").delete_suffix(".svg"), File.read(file).strip.freeze]
        end.freeze
        TOKEN = Blog::Types::String | Blog::Types::Symbol
        NAME = TOKEN | Blog::Types::Array.of(TOKEN)

        prop :name, NAME, :positional
        prop :label, Blog::Types::String.optional, default: nil

        def view_template
          i(class: classes, **labelling) { raw(safe(svg)) if context[INLINE] }
        end

        private

        def classes = Array(@name).map { ACTIONS.fetch(it, it) }

        def labelling = @label ? { role: "img", aria: { label: @label } } : { aria: { hidden: "true" } }

        def svg
          tokens = classes.flat_map { it.to_s.split }
          style = tokens.find { STYLES.include?(it) }
          glyph = tokens.find { it.start_with?("fa-") && it != style }
          SVGS.fetch("#{style.delete_prefix('fa-')}/#{glyph.delete_prefix('fa-')}")
        end
      end
    end
  end
end
