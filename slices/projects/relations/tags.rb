# frozen_string_literal: true

module Projects
  module Relations
    class Tags < Blog::DB::Relation
      use :tags

      schema :tags do
        attribute :id, ROM::SQL::Types::Serial
        attribute :name, ROM::SQL::Types::String
        attribute :color, ROM::SQL::Types::String
        attribute :scope, ROM::SQL::Types::String
        attribute :description, ROM::SQL::Types::String.optional
        attribute :created_at, ROM::SQL::Types::Time
        attribute :updated_at, ROM::SQL::Types::Time
      end
    end
  end
end
