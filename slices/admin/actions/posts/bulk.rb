# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Bulk < Action
        DONE = {
          Blog::Types::PostBulkAction["delete"] => "posts_page.toasts.bulk.deleted",
          Blog::Types::PostBulkAction["tag"] => "posts_page.toasts.bulk.tagged",
        }.freeze
        FAILED = "posts_page.toasts.bulk.failed"
        INVALID = "posts_page.toasts.bulk.invalid"
        KEY = "#"
        LONG = "long"
        REASONS = %i[not_draft not_found].freeze

        include Deps[
          "settings",
          act_on_posts: "posts.operations.act_on_posts",
          post_by_id: "posts.queries.by_id",
          posts_by_filter: "posts.queries.by_filter",
        ]

        def handle(request, response)
          case act_on_posts.call(request.params.to_h)
          in Success[*posts] then done(request, response, posts.size)
          in Failure[:record, id, reason] then failed(response, id, reason)
          in Failure[:invalid, errors] then invalid(response, errors)
          else halt 500
          end

          response.redirect_to(back(request))
        end

        private

        def back(request)
          filter = Blog::Types::PostFilterParam[request.params[:status]]

          routes.path(:admin_posts, status: filter, **Blog::Page.query(landing(request, filter)))
        end

        def done(request, response, count)
          tag = Blog::Types::Nullable::Tag[request.params[:tag]]

          toast(response, DONE.fetch(request.params[:act]), count:, tag:)
        end

        def failed(response, id, reason)
          name = post_by_id.call(id)&.title || "#{KEY}#{id}"
          code = REASONS.include?(reason) ? reason : :other

          toast(response, "#{FAILED}.#{code}", post: name)
        end

        def invalid(response, errors)
          toast(response, "#{INVALID}.#{refused(errors)}")
        end

        def landing(request, filter)
          number = Blog::Types::PageParam.call(request.params[:page]) { 1 }
          return number if number == 1

          page = Blog::Page.new(number:, size: settings.page_size[:admin])
          posts_by_filter.call(filter, page).past_end? ? number - 1 : number
        end

        def refusal(errors)
          case errors
          in [LONG, *] then LONG
          in [::String, *] then Blog::Contract::BLANK
          else Blog::Contract::FORMAT
          end
        end

        def refused(errors)
          case errors
          in { ids: } then refusal(ids)
          in { tag: [message, *] } then "tag_#{message}"
          else Blog::Contract::FORMAT
          end
        end
      end
    end
  end
end
