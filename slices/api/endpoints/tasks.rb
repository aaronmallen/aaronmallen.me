# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Tasks
      TASK = Helpers::Schema::TASK
      BULK = Helpers::Schema.bulk("tasks", TASK)
      BY_ID = Helpers::Schema.by_id(TASK)
      CADENCE = ::Tasks::Contracts::TaskCadenceContract
      CLOSED = "task %s is already done or canceled"
      CREDITS = "the whole set of who did the work: the owner, or an agent with the model it ran on; " \
                "an empty list clears it, which lists the owner again"
      CONTRIBUTORS = Helpers::Schema.list(Serializers::Task::CONTRIBUTOR).merge(description: CREDITS).freeze
      DIRECTIONS = Blog::Types::TaskMove.values.freeze
      ID = Helpers::Schema::ID
      IMPORTED = "an imported task cannot recur"
      LISTS = Blog::Types::TaskFilter.values.freeze
      SPRINT_DAY = "give sprint_on as a day, such as 2026-01-01"
      SPRINT_PAST = "a sprint opens on today or a day after it"
      SERIES = "task series"
      TAG = Helpers::Tags.schema("private")
      WORKED = {
        hours: { type: "integer", description: "whole hours worked, 0 to 9999" },
        minutes: { type: "integer", description: "minutes on top of the hours, 0 to 59" },
      }.freeze

      RECUR = {
        type: "object",
        additionalProperties: false,
        properties: {
          cadence: {
            type: "string",
            enum: Blog::Types::TaskCadence.values,
            description: [
              "days: every few days; weeks: every few weeks on a weekday; month_day: a day each month, the last",
              "day in a shorter month; month_end: the last day of each month; month_weekday: a weekday each month,",
              "such as the first Monday; yearly: a date each year",
            ].join(" "),
          },
          every: {
            type: "integer", minimum: CADENCE::EVERY.min, maximum: CADENCE::EVERY.max,
            description: "days or weeks apart, for days and weeks",
          },
          weekday: {
            type: "integer", minimum: CADENCE::WEEKDAYS.min, maximum: CADENCE::WEEKDAYS.max,
            description: "0 for Sunday to 6 for Saturday, for weeks and month_weekday",
          },
          week: {
            type: "integer", enum: CADENCE::WEEKS.sort,
            description: "1 to 4 for the first to fourth, or -1 for the last, for month_weekday",
          },
          day: {
            type: "integer", minimum: CADENCE::DAYS.min, maximum: CADENCE::DAYS.max,
            description: "the day of the month, for month_day and yearly",
          },
          month: {
            type: "integer", minimum: CADENCE::MONTHS.min, maximum: CADENCE::MONTHS.max,
            description: "1 for January to 12, for yearly",
          },
          starts_on: {
            type: "string",
            description: "for weeks, the day as YYYY-MM-DD that weeks count from; today when you leave it out",
          },
        },
        required: ["cadence"],
        description: [
          "repeats the task: when it closes, done or canceled, a copy appears on the next cadence day after today,",
          "or after the closed copy's sprint day when that day is still ahead;",
          "a field the cadence does not use is dropped; an imported task cannot recur",
        ].join(" "),
      }.freeze

      COMPLAINTS = {
        body: { "blank" => "write the comment first" },
        cadence: { "blank" => "pick a cadence" },
        contributors: {
          Blog::Contract::FORMAT => "a contributor is the owner alone, or an agent with its model, as lowercase slugs",
        },
        ended_at: {
          "blank" => "a finished session needs an end",
          Blog::Contract::FORMAT => "give the end as YYYY-MM-DDTHH:MM",
          Blog::Contract::SKIPPED => "that end falls in the hour the clocks skip",
          "future" => "a session cannot end later than now",
          "order" => "a session ends after it starts",
          "running" => "pause or complete the task before you delete its running session",
        },
        day: {
          "blank" => "month_day and yearly need a day",
          Blog::Contract::FORMAT => "that month has fewer days",
        },
        every: { "blank" => "days and weeks need every" },
        hours: {
          "blank" => "give the hours, the minutes or both",
          Blog::Contract::FORMAT => "hours run from 0 to 9999",
        },
        kind: { Blog::Contract::FORMAT => "pick one of the four link types" },
        list: { Blog::Contract::FORMAT => "pick one of the four lists" },
        minutes: { Blog::Contract::FORMAT => "minutes run from 0 to 59" },
        month: { "blank" => "yearly needs a month" },
        other_id: {
          Blog::Contract::FORMAT => "pick a task by its ID",
          "missing" => "that task is gone, so find another",
          "self" => "a task cannot link to itself",
          "taken" => "these two tasks are already linked",
        },
        project: {
          Blog::Contract::FORMAT => "give a project key, such as POD",
          "missing" => "no project has that key, or it is archived",
        },
        started_at: {
          "blank" => "a session needs a start",
          Blog::Contract::FORMAT => "give the start as YYYY-MM-DDTHH:MM",
          Blog::Contract::SKIPPED => "that start falls in the hour the clocks skip",
          "future" => "a session cannot start later than now",
        },
        starts_on: { Blog::Contract::FORMAT => "give the start as YYYY-MM-DD" },
        tag: Helpers::Tags::COMPLAINTS,
        tags: { Blog::Contract::FORMAT => Helpers::Tags::REFUSAL },
        title: { "blank" => "write the task down first" },
        week: { "blank" => "month_weekday needs a week" },
        weekday: { "blank" => "weeks and month_weekday need a weekday" },
      }.freeze

      module_function

      def missing_comment(id, comment_id) = "task #{id} has no comment with the ID #{comment_id}"

      def missing_session(id, session_id) = "task #{id} has no work session with the ID #{session_id}"

      def moment(meaning)
        { type: "string", description: "#{meaning}, as YYYY-MM-DDTHH:MM in #{Blog::TimeZone::NAME}" }
      end

      def recur(value) = value&.transform_keys(&:to_sym)
    end
  end
end
