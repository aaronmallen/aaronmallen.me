# frozen_string_literal: true

module Blog
  module DayMove
    private

    def ahead(date, now)
      day = TimeZone.parse_day(date)
      return Failure(:invalid) unless day

      day >= TimeZone.today(now) ? Success(day) : Failure(:past)
    end

    def moved(time, day, now)
      at = TimeZone.on_day(time, day)

      at > now ? Success(at) : Failure(:past)
    rescue TZInfo::PeriodNotFound
      Failure(:invalid)
    end
  end
end
