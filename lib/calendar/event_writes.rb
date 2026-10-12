# frozen_string_literal: true

module Calendar
  module EventWrites
    SERIES = "all"

    private

    def series(event, scope) = scope == SERIES && event.recurring_id

    def writable(calendar)
      return Failure(:not_found) unless calendar

      calendar.writable && !google.work?(calendar.account) ? Success(calendar) : Failure(:read_only)
    end

    def written(calendar)
      yield
      Jobs::SyncCalendar.perform_async
      Success(calendar)
    rescue Google::Error => e
      Failure([:google_failed, e.message])
    rescue TZInfo::PeriodNotFound
      Failure([:invalid, Blog::Constants::EMPTY_HASH])
    end
  end
end
