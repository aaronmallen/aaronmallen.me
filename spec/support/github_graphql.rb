# frozen_string_literal: true

module GitHubGraphQL
  URL = "https://api.github.com/graphql"
  ASSIGNED_QUERY = "search(query:"
  ISSUES_QUERY = "nodes(ids:"
  REFS_QUERY = "refs(refPrefix:"
  REPOS_QUERY = "repositories("
  VIEWER_QUERY = "viewer { id }"
  VIEWER_ID = "MDQ6VXNlcjkzMTA5NA=="

  def connect_github_token = connect_github(**GitHubCredentials::OAUTH_APP, api_token: "ghp_token")

  def github_branch(name, *commits, more: false)
    { name:, target: { history: { pageInfo: github_page_info(more, "#{name}-page-2"), nodes: commits } } }
  end

  def github_commit(sha, at:, committed: at, message: "admin: add the importer", additions: 12, deletions: 3)
    { additions:, authoredDate: github_time(at), committedDate: github_time(committed), deletions:, message:,
      oid: sha }
  end

  def github_errors(type, message = "GitHub said no", data: nil)
    github_json(data:, errors: [{ message:, type: }])
  end

  def github_issue(id, number: 1, repo: "aaronmallen/aaronmallen.me", assignees: [VIEWER_ID], **fields)
    { assignees: { nodes: assignees.map { { id: it } } }, body: "Keep them in step", id:,
      repository: { nameWithOwner: repo }, state: "OPEN", stateReason: nil, title: "Sync my issues",
      url: "https://github.com/#{repo}/issues/#{number}" }.merge(fields)
  end

  def github_issue_nodes(*nodes, remaining: 4999)
    github_json(data: { nodes:, rateLimit: github_rate_limit(remaining:), viewer: { id: VIEWER_ID } })
  end

  def github_issue_search(*nodes, more: false, remaining: 4999)
    search = { nodes:, pageInfo: github_page_info(more, "issues-page-2") }

    github_json(data: { rateLimit: github_rate_limit(remaining:), search:, viewer: { id: VIEWER_ID } })
  end

  def github_json(body) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

  def github_missing_issue
    data = { nodes: [nil], rateLimit: github_rate_limit, viewer: { id: VIEWER_ID } }

    github_errors("NOT_FOUND", "Could not resolve to a node", data:)
  end

  def github_page_info(more, cursor) = { endCursor: more ? cursor : nil, hasNextPage: more }

  def github_rate_limit(remaining: 4999, reset: Time.now + 1800)
    { limit: 5000, remaining:, resetAt: github_time(reset) }
  end

  def github_rate_limited = { status: 403, headers: { "X-RateLimit-Remaining" => "0" } }

  def github_refs_page(*branches, created_at: nil, default_branch: "main", more: false, remaining: 4999)
    refs = { pageInfo: github_page_info(more, "refs-page-2"), nodes: branches }
    repository = {
      createdAt: created_at && github_time(created_at), defaultBranchRef: default_branch && { name: default_branch },
      refs:,
    }

    github_json(data: { rateLimit: github_rate_limit(remaining:), repository: })
  end

  def github_repos_page(*repositories, more: false, remaining: 4999)
    page = { pageInfo: github_page_info(more, "repos-page-2"), nodes: repositories }

    github_json(data: { rateLimit: github_rate_limit(remaining:), viewer: { repositories: page } })
  end

  def github_repository(name, permission: "ADMIN", pushed_at: Time.now - 300)
    { nameWithOwner: name, pushedAt: pushed_at && github_time(pushed_at), viewerPermission: permission }
  end

  def github_request(query, **variables)
    a_request(:post, URL).with do |request|
      body = JSON.parse(request.body)
      body["query"].include?(query) && variables.all? { |name, value| body.dig("variables", name.to_s) == value }
    end
  end

  def github_time(time) = time.is_a?(String) ? time : time.utc.iso8601

  def stub_github(query, *responses, &block)
    stub = stub_request(:post, URL).with { |request| JSON.parse(request.body)["query"].include?(query) }
    block ? stub.to_return(&block) : stub.to_return(*responses)
  end

  def stub_github_viewer
    stub_github(VIEWER_QUERY, github_json(data: { rateLimit: github_rate_limit, viewer: { id: VIEWER_ID } }))
  end

  def unanswered_github_branch(name) = { name:, target: {} }
end

RSpec.configure do |config|
  config.include GitHubGraphQL
end
