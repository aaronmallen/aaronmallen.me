# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Files
        class Edit < View
          include Components::Files

          LIVE_TABLES = %w[shares short_codes].freeze

          prop :share, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            BackLink(href: path(:admin_files), variant: :gh, small: true, class: "editor-back") { t(".all_files") }
            PageHead(title: @share.filename)
            Card(class: "file-drawer") do
              ShareForm(share: @share, values: @values, errors: @errors)
              div(class: "file-drawer-foot") { ShareFoot(form: ShareForm, record: @share, kind: :file) }
            end
          end
        end
      end
    end
  end
end
