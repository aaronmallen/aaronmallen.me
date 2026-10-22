# frozen_string_literal: true

module Contacts
  module Relations
    class People < Blog::DB::Relation
      GOOGLE_FIELDS = %i[
        name name_prefix given_name middle_name family_name name_suffix
        phonetic_given_name phonetic_middle_name phonetic_family_name
        nickname file_as company job_title department notes
        emails phones addresses websites chats dates relations custom_fields birthday labels starred updated_at
      ].freeze
      LISTS = %i[emails phones addresses websites chats dates relations custom_fields].freeze

      schema :people, infer: true

      def emailed = where(Sequel.function(:jsonb_array_length, :emails) => 1..)

      def in_name_order = order(self[:name].asc, self[:key].asc)

      def store(google_connection_id, rows, now:)
        rows = rows.map do |row|
          row.merge(
            **row.slice(*LISTS).transform_values { Sequel.cast(JSON.generate(it), :jsonb) },
            labels: Sequel.pg_array(row[:labels], :text), google_connection_id:, created_at: now, updated_at: now,
          )
        end

        upsert = dataset.insert_conflict(target: %i[google_connection_id google_id], update: excluded(GOOGLE_FIELDS))
        upsert.multi_insert(rows)
      end

      def with_email(address) = where(Sequel.function(:lower, address) => dataset.db.select(emails))

      private

      def emails
        values = Sequel.function(:jsonb_path_query_array, :emails, "$[*].value")
        Sequel.function(:lower, Sequel.function(:jsonb_array_elements_text, values))
      end
    end
  end
end
