# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ShareDrawer < Component
        KIND = Blog::Types::Symbol.enum(:file, :group, :link)
        TITLES = KIND.values.to_h { [it, "ui.components.share_drawer.#{it}"] }.freeze

        prop :form, Blog::Types::Class
        prop :record, Blog::Types::Instance(ROM::Struct)
        prop :kind, KIND

        def self.id_for(form, record) = "#{form.scope(record)}-drawer"

        def view_template
          Dialog(**attributes) do |dialog|
            dialog.foot { ShareFoot(form: @form, record: @record, kind: @kind) }
            yield
          end
        end

        private

        def attributes
          id = self.class.id_for(@form, @record)

          { id:, title: t(TITLES.fetch(@kind)), class: "wide file-drawer", data: { dialog: true } }
        end
      end
    end
  end
end
