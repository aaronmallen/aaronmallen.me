# frozen_string_literal: true

module Social
  module Repos
    class PersonQueries < Blog::DB::Repo
      def all = people.in_name_order.to_a

      def by_id(id) = people.by_pk(id).one

      def by_keys(keys) = people.where(key: keys).to_a

      def by_name(name) = people.where(Sequel.function(:lower, :name) => name.downcase).first
    end
  end
end
