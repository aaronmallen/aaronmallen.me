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
            SharePage(
              back: path(:admin_links), back_label: t(".all_links"),
              title: Helpers::ShareLink.bare(Helpers::ShareLink.for(@link.code)),
              form: LinkForm, record: @link, kind: :link,
            ) { LinkForm(link: @link, check: @check, values: @values, errors: @errors) }
          end
        end
      end
    end
  end
end
