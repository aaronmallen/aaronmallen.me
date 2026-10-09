# frozen_string_literal: true

module Services
  module Structs
    class ServiceApp < Blog::DB::Struct
      def credentials = JSON.parse(Blog::Encryptor.new.open(self[:credentials]), symbolize_names: true)
    end
  end
end
