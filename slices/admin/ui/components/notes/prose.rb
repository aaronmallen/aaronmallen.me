# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Prose < Component
          CREATE_FORM = "note-create"

          prop :source, Blog::Types::String
          prop :written, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)

          include Deps["settings"]

          def view_template
            div(class: "post-body markdown-body") { raw(safe(html.strip)) }
          end

          private

          def html
            rendered = ::Markdown::Note.to_html(@source, origin: settings.site_origin)

            ::Markdown::WikiLinks.link(rendered) { link(it) }
          end

          def link(title)
            id = @written[title.downcase]
            return ["a", { "class" => "wl", "href" => path(:admin_note, id:) }] if id

            missing = { "type" => "submit", "form" => CREATE_FORM, "name" => "title", "value" => title }
            ["button", { "class" => "wl miss", "title" => t(".missing"), **missing }]
          end
        end
      end
    end
  end
end
