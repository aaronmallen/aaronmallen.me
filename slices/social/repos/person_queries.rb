# frozen_string_literal: true

module Social
  module Repos
    class PersonQueries < DB::Repo
      def all = people.in_name_order.to_a

      def by_id(id) = people.by_pk(id).one

      def mention_directory(texts)
        keys = Social::Mentions.keys(texts)

        Social::Mentions.new(keys.empty? ? [] : people.where(key: keys).to_a)
      end
    end
  end
end
