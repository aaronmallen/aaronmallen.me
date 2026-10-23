# frozen_string_literal: true

module Agents
  module Relations
    class AgentSessionTags < Blog::DB::Relation
      use :taggings

      schema :agent_session_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
