# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Publish < BulkAction
        FAILED = "posts_page.toasts.publish"

        include Deps[
          "settings",
          describe_post_save: "operations.describe_post_save",
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

          routes.path(:admin_posts, status: filter, **Blog::Structs::Page.query(page))
        end

        def failed(response, id, reason)
          toast(response, "#{FAILED}.#{reason}", post: post_queries.by_id(id)&.title || "#{KEY}#{id}")
        end

        def published(response, outcome, post)
          key, options = describe_post_save.call(outcome, post)

          toast(response, key, **options)
        end
      end
    end
  end
end
