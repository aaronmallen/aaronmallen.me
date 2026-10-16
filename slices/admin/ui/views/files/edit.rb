# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Files
        class Edit < View
          include Components::Files

          LIVE_TABLES = %w[share_group_files short_codes].freeze

          prop :share, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SharePage(
              back: path(:admin_files), back_label: t(".all_files"), title: @share.filename,
              form: ShareForm, record: @share, kind: :file,
            ) { ShareForm(share: @share, values: @values, errors: @errors) }
          end
        end
      end
    end
  end
end
