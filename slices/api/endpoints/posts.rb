# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module Posts
      BULK = Helpers::Schema.bulk("blog posts")
      ID = Helpers::Schema::ID
      LONG_NOTE = "runs over #{::Posts::Contracts::PostContract::EDIT_NOTE_LIMIT} characters".freeze
      NEEDED_NOTE = "is needed when the body of a published post changes: say what changed and why"
      TAG = Helpers::Tags.schema("public")
      URL = "needs a URL starting with http:// or https://"

      CONTRACTS = [
        ::Posts::Contracts::EditNoteContract, ::Posts::Contracts::PostContract, ::Posts::Contracts::PostSeoContract,
      ].freeze
      COMPLAINTS = {
        canonical_url: { Blog::Contract::FORMAT => "canonical_url #{URL}" },
        edit_note: {
          Blog::Contract::BLANK => "edit_note #{NEEDED_NOTE}",
          "long" => "edit_note #{LONG_NOTE}",
        },
        note: {
          Blog::Contract::BLANK => "note can't be blank: say what changed and why",
          "long" => "note #{LONG_NOTE}",
        },
        og_image_url: { Blog::Contract::FORMAT => "og_image_url #{URL}" },
        publish_at: {
          Blog::Contract::FORMAT => "publish_at needs a time as YYYY-MM-DDTHH:MM, in #{Blog::TimeZone::NAME} time",
        },
        slug: {
          Blog::Contract::BLANK => "slug needs a letter or number, from itself or from the title",
          Blog::Contract::FORMAT => "slug takes lowercase letters, numbers and single dashes",
          "locked" => "slug cannot change once the post is published",
          "reserved" => "slug belongs to a page on the site",
          "taken" => "slug belongs to another post",
        },
        syndication_body: {
          ::Posts::Contracts::PostContract::ANNOUNCEMENT_TOO_LONG =>
            "syndication_body is empty, and the title and link sent in its place run over a network's limit",
          Blog::Contract::TOO_LONG => "syndication_body runs over a network's limit",
        },
        tag: Helpers::Tags::COMPLAINTS,
        tags: { Blog::Contract::FORMAT => "tags are each #{Helpers::Tags::FORMAT}" },
      }.freeze

      module_function

      def form_complaints(errors) = Helpers::Wording.complaints(errors, COMPLAINTS, named: true)

      def missing_edit(id, edit_id) = "blog post #{id} has no edit with the ID #{edit_id}"
    end
  end
end
