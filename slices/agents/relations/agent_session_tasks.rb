# frozen_string_literal: true

module Agents
  module Relations
    class AgentSessionTasks < Blog::DB::Relation
      schema :agent_session_tasks, infer: true
    end
  end
end
