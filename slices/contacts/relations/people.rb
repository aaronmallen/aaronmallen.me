# frozen_string_literal: true

module Contacts
  module Relations
    class People < Blog::DB::Relation
      schema :people, infer: true

      def in_name_order = order(self[:name].asc, self[:key].asc)
    end
  end
end
