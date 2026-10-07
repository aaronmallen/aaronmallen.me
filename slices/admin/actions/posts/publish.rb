# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Publish < BulkAction
        FAILED = "posts_page.toasts.publish"
        TOASTS = "post_form.toasts"

        include Deps[
          "settings",
          post_queries: "posts.repos.post_queries",
          publish_draft: "posts.operations.publish_draft",
        ]

        def handle(request, response)
          id = record_id(request)

          case publish_draft.call(id)
          in Success[outcome, post] then published(response, outcome, post)
          in Failure(:not_found) then halt 404
          in Failure(:published) then failed(response, id, :published)
          in Failure[:invalid, _] then failed(response, id, :invalid)
          else halt 500
          end

          response.redirect_to(back(request))
        end

        private

        def back(request)
          filter = Blog::Types::PostFilterParam[request.params[:status]]
          page = landing(request) { post_queries.by_filter(filter, it).past_end? }

          routes.path(:admin_posts, status: filter, **Blog::Page.query(page))
        end

        def failed(response, id, reason)
          toast(response, "#{FAILED}.#{reason}", post: post_queries.by_id(id)&.title || "#{KEY}#{id}")
        end

        def published(response, outcome, post)
          date = i18n.l(Blog::TimeZone.local(post.published_at), format: :medium) if post.published_at

          toast(response, "#{TOASTS}.#{outcome}", date:)
        end
      end
    end
  end
end
