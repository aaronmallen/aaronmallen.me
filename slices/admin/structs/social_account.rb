# frozen_string_literal: true

module Admin
  module Structs
    SocialAccount = Data.define(:id, :label, :network, :network_label, :selected) do
      def handle = host ? label.delete_suffix("@#{host}") : label

      def host = label[/\A@[^@]+@(.+)\z/, 1]
    end
  end
end
