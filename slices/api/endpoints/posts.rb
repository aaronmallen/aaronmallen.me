# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Posts
      BULK = Helpers::Schema.bulk("blog posts")
      ID = Helpers::Schema::ID
      LONG_NOTE = "runs over #{::Posts::Contracts::PostContract::EDIT_NOTE_LIMIT} characters".freeze
      TAG = Helpers::Tags.schema("public")
      URL = "needs a URL starting with http:// or https://"

      COMPLAINTS = { tag: Helpers::Tags::COMPLAINTS }.freeze

      REASONS = Helpers::Wording::SHARED.merge(
        "announcement_too_long" => "is empty, and the title and link sent in its place run over a network's limit",
        "locked" => "cannot change once the post is published",
        "reserved" => "belongs to a page on the site",
        "taken" => "belongs to another post",
        "too_long" => "runs over a network's limit",
      ).freeze

      FIELD_REASONS = {
        canonical_url: { Blog::Contract::FORMAT => URL },
        edit_note: {
          "blank" => "is needed when the body of a published post changes: say what changed and why",
          "long" => LONG_NOTE,
        },
        note: { "blank" => "can't be blank: say what changed and why", "long" => LONG_NOTE },
        og_image_url: { Blog::Contract::FORMAT => URL },
        publish_at: { Blog::Contract::FORMAT => "needs a time as YYYY-MM-DDTHH:MM, in #{Blog::TimeZone::NAME} time" },
        slug: {
          "blank" => "needs a letter or number, from itself or from the title",
          Blog::Contract::FORMAT => "takes lowercase letters, numbers and single dashes",
        },
        tags: { Blog::Contract::FORMAT => "are each #{Helpers::Tags::FORMAT}" },
      }.freeze

      module_function

      def field_reason(field, code) = FIELD_REASONS.dig(field, code) || Helpers::Wording.plain(code, REASONS)

      def form_complaints(errors) = errors.to_h { |field, (code)| [field, ["#{field} #{field_reason(field, code)}"]] }

      def missing_edit(id, edit_id) = "blog post #{id} has no edit with the ID #{edit_id}"
    end
  end
end
