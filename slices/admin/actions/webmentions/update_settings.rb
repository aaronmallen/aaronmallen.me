# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class UpdateSettings < Action
        TOASTS = "webmentions_page.toasts"
        TOGGLES = ::Social::Operations::UpdateWebmentionSettings::TOGGLES

        include Deps[update_webmention_settings: "social.operations.update_webmention_settings"]

        def handle(request, response)
          toast(response, "#{TOASTS}.#{save(request)}")
          response.redirect_to(routes.path(:admin_webmention_settings))
        end

        private

        def save(request)
          case update_webmention_settings.call(**settings(request))
            in Success(_) then :saved
            in Failure(:unchanged) then :unchanged
            else halt :internal_server_error
          end
        end

        def settings(request)
          params = Blog::Types::Fields[request.params[:settings]]
          toggles = params.slice(*TOGGLES).transform_values { Blog::Types::Checkbox[it] }
          return toggles unless params.key?(:single_author_hosts)

          toggles.merge(single_author_hosts: Blog::Types::Normalized::Hosts[params[:single_author_hosts]])
        end
      end
    end
  end
end
