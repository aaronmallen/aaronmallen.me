# frozen_string_literal: true

module Agents
  module Structs
    class ArtifactVersion < Blog::DB::Struct
      def agent? = !agent.nil?
    end
  end
end
