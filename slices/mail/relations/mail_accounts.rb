# frozen_string_literal: true

module Mail
  module Relations
    class MailAccounts < Blog::DB::Relation
      CONTACT_FORM = { provider: Blog::Types::MailProvider["contact_form"] }.freeze
      CONTACT_FORM_NAME = "Contact form"

      schema :mail_accounts, infer: true

      def contact_form = where(CONTACT_FORM)

      def contact_form_id
        where(CONTACT_FORM).pluck(:id).first || dataset.insert(**CONTACT_FORM, name: CONTACT_FORM_NAME)
      end

      def form_last = order(Sequel.case([[CONTACT_FORM, 1]], 0), self[:id].asc)
    end
  end
end
