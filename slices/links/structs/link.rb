# frozen_string_literal: true

module Links
  module Structs
    Link = Data.define(:kind, :id, :title, :day, :url, :scoped) do
      def initialize(scoped: false, **) = super
    end
  end
end
