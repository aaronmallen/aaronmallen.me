# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ShareFoot < Component
        DELETES = ShareDrawer::KIND.values.to_h { [it, "ui.components.share_foot.#{it}"] }.freeze

        prop :form, Blog::Types::Class
        prop :record, Blog::Types::Instance(ROM::Struct)
        prop :kind, ShareDrawer::KIND

        def view_template
          Button(
            small: true, variant: :warn, type: "submit", form: @form.delete_id(@record),
            icon: "fa-regular fa-trash-can",
          ) { t(DELETES.fetch(@kind)) }
          Button(small: true, variant: :pri, type: "submit", form: @form.form_id(@record)) { t(".save") }
        end
      end
    end
  end
end
