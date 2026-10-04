# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Publish < Action
        FAILED = "posts_page.toasts.publish"
        KEY = "#"
        TOASTS = "post_form.toasts"

        include Deps[
          "settings",
          post_by_id: "posts.queries.by_id",
          posts_by_filter: "posts.queries.by_filter",
          publish_draft: "posts.operations.publish_draft",
        ]

        def handle(request, response)
          id = record_id(request)

          case publish_draft.call(id)
          in Success[outcome, post] then published(response, outcome, post)
          in Failure(:not_found) then halt 404
          in Failure(:not_draft) then failed(response, id, :not_draft)
          in Failure[:invalid, _] then failed(response, id, :invalid)
          else halt 500
          end

          response.redirect_to(back(request))
        end

        private

        def back(request)
          filter = Blog::Types::PostFilterParam[request.params[:status]]

          routes.path(:admin_posts, status: filter, **Blog::Page.query(landing(request, filter)))
        end

        def failed(response, id, reason)
          toast(response, "#{FAILED}.#{reason}", post: post_by_id.call(id)&.title || "#{KEY}#{id}")
        end

        def landing(request, filter)
          number = Blog::Types::PageParam.call(request.params[:page]) { 1 }
          return number if number == 1

          page = Blog::Page.new(number:, size: settings.page_size[:admin])
          posts_by_filter.call(filter, page).past_end? ? number - 1 : number
        end

        def published(response, outcome, post)
          date = i18n.l(Blog::TimeZone.local(post.published_at), format: :medium) if post.published_at

          toast(response, "#{TOASTS}.#{outcome}", date:)
        end
      end
    end
  end
end
