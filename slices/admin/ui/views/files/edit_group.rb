# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Files
        class EditGroup < View
          include Components::Files

          LIVE_TABLES = %w[share_group_files share_groups short_codes].freeze

          prop :group, Blog::Types::Instance(ROM::Struct)
          prop :values, Blog::Types::Hash.optional, default: nil
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            BackLink(href: path(:admin_files), variant: :gh, small: true, class: "editor-back") { t(".all_files") }
            PageHead(title: t(".title", code: @group.code))
            Card(class: "file-drawer") do
              GroupForm(group: @group, values: @values, errors: @errors)
              div(class: "file-drawer-foot") { ShareFoot(form: GroupForm, record: @group, kind: :group) }
            end
          end
        end
      end
    end
  end
end
