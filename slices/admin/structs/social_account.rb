# frozen_string_literal: true

module Admin
  module Structs
    SocialAccount = Data.define(:configured, :id, :label, :network, :network_label, :selected) do
      def name = network

      def value = id
    end
  end
end
