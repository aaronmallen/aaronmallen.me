# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Bulk < Action
        ADD = UI::Components::Files::Bulk::ADD
        DONE = {
          ADD => "files_page.toasts.bulk.added", UI::Components::Files::Bulk::GROUP => "files_page.toasts.bulk.grouped",
        }.freeze
        FAILED = "files_page.toasts.bulk.failed"

        include Deps[
          add_shares_to_group: "shares.operations.add_shares_to_group",
          group_shares: "shares.operations.group_shares",
        ]

        def handle(request, response)
          act = request.params[:act]
          halt 422 unless DONE.key?(act)

          key, details = moved(request, act, picked_ids(request))
          toast(response, key, **details)
          response.redirect_to(routes.path(:admin_files))
        end

        private

        def failed(reason) = ["#{FAILED}.#{reason}", {}]

        def move(request, act, ids)
          return group_shares.call(ids) unless act == ADD

          group_id = Blog::Types::IdParam[request.params[:group_id]]
          group_id ? add_shares_to_group.call(group_id, ids) : :no_group
        end

        def moved(request, act, ids)
          case move(request, act, ids)
            in Success(group) then [DONE.fetch(act), { count: ids.size, name: group.name || group.code }]
            in Failure(:not_found) then failed(:not_found)
            in Failure[:invalid, { ids: [reason, *] }] then failed(reason)
            in :no_group then failed(:no_group)
          end
        end
      end
    end
  end
end
