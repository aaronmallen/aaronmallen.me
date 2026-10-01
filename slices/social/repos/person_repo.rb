# frozen_string_literal: true

module Social
  module Repos
    class PersonRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def all = people.in_name_order.to_a

      def by_id(id) = people.by_pk(id).one
    end
  end
end
