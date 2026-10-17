# frozen_string_literal: true

module Mail
  module Jobs
    class RecleanMailHtml < Blog::Job
      DONE = "Cleaned stored mail HTML again, leaving %d threads Gmail no longer has as they were"

      include Deps[reclean_mail_html: "operations.reclean_mail_html"]

      def perform(after = 0, gone = 0)
        case reclean_mail_html.call(after)
          in Success(nil, more) then logger.info(format(DONE, gone + more))
          in Success(last, more) then self.class.perform_in(BackfillGmail::PACE, last, gone + more)
          in Failure(:gmail_rate_limited, _) then self.class.perform_in(BackfillGmail::RATE_LIMIT_WAIT, after, gone)
          in Failure(_, message) then raise Error, message
        end
      end
    end
  end
end
