# frozen_string_literal: true

module Social
  module Repos
    class PersonRepo < Blog::DB::Repo
      stamped_commands :create, :update
      commands delete: :by_pk

      def all = people.in_name_order.to_a

      def by_id(id) = people.by_pk(id).one

      def by_keys(keys) = people.where(key: keys).to_a
    end
  end
end
