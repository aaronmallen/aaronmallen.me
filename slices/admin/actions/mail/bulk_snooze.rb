# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class BulkSnooze < Bulk
        SNOOZED = "mail_page.toasts.bulk.snoozed"

        include Deps[snooze_messages: "mail.operations.snooze_messages"]

        private

        def act(params)
          ids = Array(params[:ids]).filter_map { Blog::Types::IdParam[it] }.uniq
          at = Blog::TimeZone.parse_time(params[:pick])
          return Failure[:invalid, { ids: [Blog::Contract::BLANK] }] if ids.empty?
          return Failure[:invalid, { ids: [LONG] }] if ids.size > Blog::Contract::MAX_IDS
          return Failure[:invalid, { pick: [Blog::Contract::FORMAT] }] unless at&.>(Time.now)

          snooze_messages.call(ids, at)
        end

        def done(request, response, records)
          at = Blog::TimeZone.parse_time(request.params[:pick])
          date = i18n.l(Blog::TimeZone.local_date(at), format: :medium)

          toast(response, SNOOZED, count: records.size, date:)
        end

        def refusal(errors) = errors.key?(:pick) ? "past" : super
      end
    end
  end
end
