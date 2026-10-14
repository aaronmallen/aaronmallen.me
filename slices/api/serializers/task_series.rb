# frozen_string_literal: true

module API
  module Serializers
    class TaskSeries < Serializer
      NUMBER = Helpers::Schema.nullable(Helpers::Schema::INTEGER)

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER.merge(description: "the series, which list_task_series, pause_task_series " \
                                                          "and resume_task_series take"),
          cadence: { type: "string", enum: Blog::Types::TaskCadence.values },
          every: NUMBER.merge(description: "days or weeks apart, for days and weeks"),
          weekday: NUMBER.merge(description: "0 for Sunday to 6 for Saturday, for weeks and month_weekday"),
          week: NUMBER.merge(description: "1 to 4 for the first to fourth, or -1 for the last, for month_weekday"),
          day: NUMBER.merge(description: "the day of the month, for month_day and yearly"),
          month: NUMBER.merge(description: "1 for January to 12, for yearly"),
          starts_on: Helpers::Schema.nullable(Helpers::Schema::DAY).merge(
            description: "the day weeks count from, for weeks",
          ),
          paused: Helpers::Schema::BOOLEAN.merge(description: "a paused series makes no copy when its task closes"),
        },
      ).freeze

      schema_attributes

      def day(series) = series.day

      def starts_on(series) = series.starts_on&.iso8601
    end
  end
end
