# frozen_string_literal: true

module Admin
  module Operations
    class DescribePostSave
      TOASTS = "post_form.toasts"

      include Deps["i18n"]

      def call(outcome, post)
        published_at = post.published_at

        ["#{TOASTS}.#{outcome}", { date: published_at && i18n.l(Blog::TimeZone.local(published_at), format: :medium) }]
      end
    end
  end
end
