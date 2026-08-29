# frozen_string_literal: true

module Projects
  module Structs
    class WorkEntry < Blog::DB::Struct
      def current? = to_year.nil?
    end
  end
end
