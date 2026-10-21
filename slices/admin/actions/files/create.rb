# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Files
      class Create < Action
        ADDED = "files_page.toasts.added"
        GROUPED = "files_page.toasts.grouped"
        JSON_TYPE = "application/json"
        STATUSES = {
          blank: :unprocessable_content,
          invalid: :unprocessable_content,
          unavailable: :service_unavailable,
        }.freeze
        TOASTS = {
          nil => "files_page.toasts.uploaded",
          blank: "files_page.toasts.failed.blank",
          invalid: "files_page.toasts.failed.invalid",
          unavailable: "files_page.toasts.failed.unavailable",
        }.freeze

        include Deps[
          add_share_group_files: "shares.operations.add_share_group_files",
          upload_share: "shares.operations.upload_share", upload_share_group: "shares.operations.upload_share_group",
        ]

        config.formats.accept :html, :json

        def handle(request, response)
          links, reason, key, count = sent(request)
          return answer(response, links, reason, i18n.t!(key, count:)) if json?(request)

          toast(response, key, count:)
          response.redirect_to(routes.path(:admin_files))
        end

        private

        def add(id, files)
          case add_share_group_files.call(id, files)
            in Success(group) then [[Helpers::ShareLink.for(group.code)], nil, ADDED, files.size]
            in Failure(:not_found) then halt :not_found
            in Failure[reason, *] then [[], reason, TOASTS.fetch(reason), 0]
          end
        end

        def answer(response, links, reason, message)
          response.status = reason ? STATUSES.fetch(reason) : :created
          response.format = :json
          response.body = JSON.generate({ links:, message: })
        end

        def json?(request) = request.get_header("HTTP_ACCEPT").to_s.start_with?(JSON_TYPE)

        def sent(request)
          files = Array(request.params[:files]).select { it.is_a?(::Hash) && it[:tempfile] }
          group_id = Blog::Types::IdParam[request.params[:group_id]]
          return add(group_id, files) if group_id

          request.params[:group] == Blog::Constants::CHECKED ? upload_group(files) : upload(files)
        end

        def upload(files)
          return [[], :blank, TOASTS.fetch(:blank), 0] if files.empty?

          links = []
          files.each do |file|
            case upload_share.call(file)
              in Success(share) then links << Helpers::ShareLink.for(share.code)
              in Failure[reason, *] then return [links, reason, TOASTS.fetch(reason), links.size]
            end
          end
          [links, nil, TOASTS.fetch(nil), links.size]
        end

        def upload_group(files)
          case upload_share_group.call(files)
            in Success(group) then [[Helpers::ShareLink.for(group.code)], nil, GROUPED, files.size]
            in Failure[reason, *] then [[], reason, TOASTS.fetch(reason), 0]
          end
        end
      end
    end
  end
end
