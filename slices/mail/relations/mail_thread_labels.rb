# frozen_string_literal: true

module Mail
  module Relations
    class MailThreadLabels < Blog::DB::Relation
      schema :mail_thread_labels, infer: true
    end
  end
end
