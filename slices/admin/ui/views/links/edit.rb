# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Links
        class Edit < View
          include Components::Links

          prop :link, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            BackLink(href: path(:admin_links), variant: :gh, small: true, class: "editor-back") { t(".all_links") }
            PageHead(title: Helpers::ShareLink.bare(Helpers::ShareLink.for(@link.code)))
            Card(class: "file-drawer") do
              LinkForm(link: @link, values: @values, errors: @errors)
              div(class: "file-drawer-foot") { ShareFoot(form: LinkForm, record: @link, kind: :link) }
            end
          end
        end
      end
    end
  end
end
