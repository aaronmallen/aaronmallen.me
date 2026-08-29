# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class UpdateSettings < Action
        SETTINGS = %i[receive send_on_publish auto_approve_known_authors enable_on_new_posts accept_bridgy].freeze
        TOASTS = "webmentions_page.toasts"

        include Deps[update_webmention_settings: "social.operations.update_webmention_settings"]

        def handle(request, response)
          toast(response, "#{TOASTS}.#{save(request)}")
          response.redirect_to(routes.path(:admin_webmentions, status: filter(request)))
        end

        private

        def filter(request) = Blog::Types::WebmentionStatusParam[request.params[:status]]

        def save(request)
          case update_webmention_settings.call(**settings(request))
          in Success(_) then :saved
          in Failure(:unchanged) then :unchanged
          else halt 500
          end
        end

        def settings(request)
          params = Blog::Types::Fields[request.params[:settings]]

          params.slice(*SETTINGS).transform_values { Blog::Types::Checkbox[it] }
        end
      end
    end
  end
end
