# frozen_string_literal: true

module Tasks
  module Structs
    class TaskComment < Blog::DB::Struct
      def synced? = !remote_id.nil?
    end
  end
end
