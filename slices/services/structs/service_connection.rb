# frozen_string_literal: true

module Services
  module Structs
    class ServiceConnection < Blog::DB::Struct
      CREDENTIALS = "credentials"

      def by_credentials? = credentials[:auth] == CREDENTIALS

      def credentials = JSON.parse(Services::Encryptor.new.open(self[:credentials]), symbolize_names: true)
    end
  end
end
