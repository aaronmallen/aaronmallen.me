# frozen_string_literal: true

module Agents
  module Structs
    class Artifact < Blog::DB::Struct
      def title_by_agent? = !title_agent.nil?
    end
  end
end
