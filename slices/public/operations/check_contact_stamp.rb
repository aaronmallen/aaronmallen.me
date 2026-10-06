# frozen_string_literal: true

module Public
  module Operations
    class CheckContactStamp
      MILLISECONDS = IssueContactStamp::MILLISECONDS
      SECONDS_PER_HOUR = 3_600
      STAMP = /\A(?<issued>\d{1,15})#{IssueContactStamp::SEPARATOR}\h{64}\z/o

      include Deps["settings", issue: "operations.issue_contact_stamp"]

      def call(stamp, at = Time.now)
        found = STAMP.match(stamp.to_s)
        return false unless found

        issued = Rational(found[:issued].to_i, MILLISECONDS)
        signed?(found[0], issued) && (at.to_r - issued).between?(minimum, expiry)
      end

      private

      def expiry = settings.contact[:stamp_expiry_hours] * SECONDS_PER_HOUR

      def minimum = settings.contact[:minimum_submit_seconds]

      def signed?(stamp, issued) = Rack::Utils.secure_compare(stamp, issue.call(Time.at(issued)))
    end
  end
end
