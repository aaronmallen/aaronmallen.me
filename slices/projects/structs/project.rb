# frozen_string_literal: true

module Projects
  module Structs
    class Project < Blog::DB::Struct
      def archived? = status == Blog::Types::ProjectStatus["archived"]
    end
  end
end
