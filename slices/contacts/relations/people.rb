# frozen_string_literal: true

module Contacts
  module Relations
    class People < Blog::DB::Relation
      schema :people, infer: true

      def emailed = where(Sequel.function(:jsonb_array_length, :emails) => 1..)

      def in_name_order = order(self[:name].asc, self[:key].asc)

      def with_email(address) = where(Sequel.function(:lower, address) => dataset.db.select(emails))

      private

      def emails
        values = Sequel.function(:jsonb_path_query_array, :emails, "$[*].value")
        Sequel.function(:lower, Sequel.function(:jsonb_array_elements_text, values))
      end
    end
  end
end
