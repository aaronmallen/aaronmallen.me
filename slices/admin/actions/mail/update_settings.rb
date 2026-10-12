# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class UpdateSettings < Action
        RULES = %i[contact_form people needs_reply starred important skip_notifications].freeze
        TOGGLES = %i[shown sends].freeze

        include Deps[update_mail_settings: "mail.operations.update_mail_settings"]

        def handle(request, response)
          update_mail_settings.call(rules: toggled(request.params[:settings], RULES), accounts: accounts(request))
          toast(response, "mail_page.toasts.settings_saved")
          response.redirect_to(routes.path(:admin_mail_settings))
        end

        private

        def accounts(request)
          Blog::Types::Fields[request.params[:accounts]].filter_map do |id, toggles|
            id = Blog::Types::IdParam[id.to_s]
            [id, toggled(toggles, TOGGLES)] if id
          end.to_h
        end

        def toggled(params, names)
          Blog::Types::Fields[params].slice(*names).transform_values { Blog::Types::Checkbox[it] }
        end
      end
    end
  end
end
