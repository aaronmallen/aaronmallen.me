# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Links
        class Edit < View
          include Components::Links

          LIVE_TABLES = %w[short_codes short_link_checks short_links].freeze

          prop :link, Blog::Types::Instance(ROM::Struct)
          prop :check, Blog::Types::Instance(ROM::Struct).optional, default: nil
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            BackLink(href: path(:admin_links), variant: :gh, small: true, class: "editor-back") { t(".all_links") }
            PageHead(title: Helpers::ShareLink.bare(Helpers::ShareLink.for(@link.code)))
            Card(class: "file-drawer") do
              LinkForm(link: @link, check: @check, values: @values, errors: @errors)
              div(class: "file-drawer-foot") { ShareFoot(form: LinkForm, record: @link, kind: :link) }
            end
          end
        end
      end
    end
  end
end
