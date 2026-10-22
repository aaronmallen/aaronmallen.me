# frozen_string_literal: true

module Mail
  module Relations
    class People < Blog::DB::Relation
      schema :people, infer: true

      def addresses = dataset.unordered.select(emails)

      private

      def emails
        values = Sequel.function(:jsonb_path_query_array, :emails, "$[*].value")
        Sequel.function(:lower, Sequel.function(:jsonb_array_elements_text, values))
      end
    end
  end
end
