# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Decisions
      ID = Helpers::Schema::ID
      NOTE = { type: "string", description: "why it changed; a resolved or dropped decision needs one" }.freeze
      REASON = { type: "string", description: "why, in Markdown" }.freeze

      COMPLAINTS = {
        body: { "blank" => "write the comment first" },
        note: {
          "blank" => "a resolved or dropped decision needs a note to say why it changed",
          "long" => "keep the note to 500 characters",
        },
        option_id: {
          Blog::Contract::FORMAT => "pick an option by its ID",
          "chosen" => "the decision was resolved with this option, so reopen it first",
          "missing" => "pick one of this decision's own options",
        },
        problem: { "blank" => "write the problem down first" },
        reason: { "blank" => "write down why first" },
        tags: { Blog::Contract::FORMAT => "tags are lowercase words" },
        title: { "blank" => "give it a title first" },
      }.freeze

      module_function

      def missing_comment(id, comment_id) = "decision #{id} has no comment with the ID #{comment_id}"

      def missing_option(id, option_id) = "decision #{id} has no option with the ID #{option_id}"
    end
  end
end
