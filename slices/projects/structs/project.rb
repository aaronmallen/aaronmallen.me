# frozen_string_literal: true

module Projects
  module Structs
    class Project < Blog::DB::Struct
      def archived? = !archived_on.nil?

      def slug = Blog::Types::Normalized::Slug.call(name) { nil }

      def status = archived? ? "archived" : "active"
    end
  end
end
