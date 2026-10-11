# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Links
      class Create < Action
        CREATED = 201
        JSON_TYPE = "application/json"
        SHORTENED = "links_page.toasts.shortened"

        include Deps[
          build_links_page: "operations.build_links_page",
          create_short_link: "shares.operations.create_short_link",
          index_view: "ui.views.links.index",
          short_link_queries: "shares.repos.short_link_queries",
        ]

        config.formats.accept :html, :json

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:link]]
          again = shortened_before(params)
          return refuse(response, params, again:) if again

          case create_short_link.call(params.slice(:destination, :code))
            in Success(link) then created(request, response, link)
            in Failure[:invalid, errors] then refuse(response, params, errors:)
            else halt 500
          end
        end

        private

        def answer(response, link)
          response.status = CREATED
          response.format = :json
          response.body = JSON.generate({ link: Helpers::ShareLink.for(link.code), message: i18n.t!(SHORTENED) })
        end

        def created(request, response, link)
          return answer(response, link) if request.get_header("HTTP_ACCEPT").to_s.start_with?(JSON_TYPE)

          toast(response, SHORTENED)
          response.redirect_to(routes.path(:admin_links))
        end

        def refuse(response, params, **)
          response.status = 422
          response.format = :html
          response.render(index_view, **build_links_page.call(params:, **))
        end

        def shortened_before(params)
          destination = Blog::Types::TrimmedText[params[:destination]]
          return if destination.empty? || Blog::Types::TrimmedText[params[:again]] == destination

          short_link_queries.latest_to(destination)
        end
      end
    end
  end
end
