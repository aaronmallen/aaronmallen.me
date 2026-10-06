# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Tasks
      BULK = Schema.bulk("tasks")
      CLOSED = "task %s is already done or canceled"
      CREDITS = "the whole set of who did the work: the owner, or an agent with the model it ran on; " \
                "an empty list clears it, which lists the owner again"
      CONTRIBUTORS = Schema.list(Serializers::Task::CONTRIBUTOR).merge(description: CREDITS).freeze
      DIRECTIONS = Blog::Types::TaskMove.values.freeze
      ID = Schema::ID
      LISTS = Blog::Types::TaskFilter.values.freeze
      SPRINT_PAST = "a sprint opens on today or a day after it"
      TAG = { type: "string", description: "one private tag, lowercase words" }.freeze
      WORKED = {
        hours: { type: "integer", description: "whole hours worked, 0 to 9999" },
        minutes: { type: "integer", description: "minutes on top of the hours, 0 to 59" },
      }.freeze

      COMPLAINTS = {
        body: { "blank" => "write the comment first" },
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
        hours: {
          "blank" => "give the hours, the minutes or both",
          Blog::Contract::FORMAT => "hours run from 0 to 9999",
        },
        kind: { Blog::Contract::FORMAT => "pick one of the four link types" },
        list: { Blog::Contract::FORMAT => "pick one of the four lists" },
        minutes: { Blog::Contract::FORMAT => "minutes run from 0 to 59" },
        other_id: {
          Blog::Contract::FORMAT => "pick a task by its ID",
          "missing" => "that task is gone, so find another",
          "self" => "a task cannot link to itself",
          "taken" => "these two tasks are already linked",
        },
        started_at: {
          "blank" => "a session needs a start",
          Blog::Contract::FORMAT => "give the start as YYYY-MM-DDTHH:MM",
          Blog::Contract::SKIPPED => "that start falls in the hour the clocks skip",
          "future" => "a session cannot start later than now",
        },
        tag: { "blank" => "name the tag first", Blog::Contract::FORMAT => "a tag is lowercase words" },
        tags: { Blog::Contract::FORMAT => "tags are lowercase words" },
        title: { "blank" => "write the task down first" },
      }.freeze

      module_function

      def missing_comment(id, comment_id) = "task #{id} has no comment with the ID #{comment_id}"

      def missing_session(id, session_id) = "task #{id} has no work session with the ID #{session_id}"

      def moment(meaning)
        { type: "string", description: "#{meaning}, as YYYY-MM-DDTHH:MM in #{Blog::TimeZone::NAME}" }
      end
    end
  end
end
