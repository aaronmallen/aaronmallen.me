# frozen_string_literal: true

module Tasks
  module Jobs
    class CreditAgents < Blog::Job
      include Deps[credit_agents: "operations.credit_agents"]

      sidekiq_options retry: 3

      def perform(repo, issues, agents) = credit_agents.call(repo, issues, agents)
    end
  end
end
