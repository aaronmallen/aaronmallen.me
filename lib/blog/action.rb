# frozen_string_literal: true

require "hanami/action"
require "dry/monads"

module Blog
  class Action < Hanami::Action
    NOT_FOUND_PAGE = "public/404.html"

    module CSRFToken
      private

      def request_csrf_token(request)
        token = super
        token if token.is_a?(::String)
      end
    end

    include Dry::Monads[:result]

    def self.verify_csrf_under_test
      before :set_csrf_token, :verify_csrf_token if Hanami.env?(:test)
    end

    private

    def forbid_caching(_request, response)
      response.cache_control(:private, :no_store)
    end

    def not_found(response)
      response.format = :html
      halt 404, Hanami.app.root.join(NOT_FOUND_PAGE).read
    end

    def path_param(request, name) = ::Rack::Utils.unescape_path(request.params[name])

    def requested_page(request, response)
      Structs::Page.new(number: Types::PageParam.call(request.params[:page]) { not_found(response) }, size: page_size)
    end
  end
end
