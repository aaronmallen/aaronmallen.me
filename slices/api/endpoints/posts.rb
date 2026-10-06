# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Posts
      BULK = Schema.bulk("blog posts")
      ID = Schema::ID
      INVALID = "is not valid"
      TAG = { type: "string", description: "one public tag, lowercase words" }.freeze
      URL = "needs a URL starting with http:// or https://"

      COMPLAINTS = {
        tag: { "blank" => "name the tag first", Blog::Contract::FORMAT => "a tag is lowercase words" },
      }.freeze

      REASONS = {
        "announcement_too_long" => "is empty, and the title and link sent in its place run over a network's limit",
        "blank" => "is empty",
        Blog::Contract::CONTROL => "holds a control character",
        "locked" => "cannot change once the post is published",
        "reserved" => "belongs to a page on the site",
        Blog::Contract::SKIPPED => "names a time the clocks skip in Chicago",
        "taken" => "belongs to another post",
        "too_long" => "runs over a network's limit",
        "unknown_mention" => "mentions someone who is not in the directory",
      }.freeze

      FIELD_REASONS = {
        canonical_url: { Blog::Contract::FORMAT => URL },
        edit_note: {
          "blank" => "is needed when the body of a published post changes: say what changed and why",
          "long" => "runs over 500 characters",
        },
        note: { "blank" => "can't be blank: say what changed and why", "long" => "runs over 500 characters" },
        og_image_url: { Blog::Contract::FORMAT => URL },
        publish_at: { Blog::Contract::FORMAT => "needs a time as YYYY-MM-DDTHH:MM, in Chicago time" },
        slug: {
          "blank" => "needs a letter or number, from itself or from the title",
          Blog::Contract::FORMAT => "takes lowercase letters, numbers and single dashes",
        },
        tags: { Blog::Contract::FORMAT => "each take lowercase letters, numbers and single dashes" },
      }.freeze

      module_function

      def field_reason(field, code) = FIELD_REASONS.dig(field, code) || REASONS.fetch(code, INVALID)

      def form_complaints(errors) = errors.to_h { |field, (code)| [field, ["#{field} #{field_reason(field, code)}"]] }

      def missing_edit(id, edit_id) = "blog post #{id} has no edit with the ID #{edit_id}"
    end
  end
end
