# frozen_string_literal: true

module LinearGraphQL
  URL = "https://api.linear.app/graphql"
  ASSIGNED_QUERY = "assignedIssues("
  CLIENT_KEYS = %w[linear.client record.linear.client].freeze
  HISTORY_QUERY = "history(first:"
  ISSUES_QUERY = "issues(first:"
  KEY = "lin_api_one"
  VIEWER_ID = "0b7f5a52-viewer"

  def connect_linear(*api_keys)
    Record::Slice.start(:linear)
    allow(Hanami.app.settings).to receive(:linear).and_return({ api_keys: })
    client = Record::Providers::LinearProvider.client(Hanami.app["settings"], Hanami.app["http"])
    CLIENT_KEYS.each { replace_component(it, client) }
  end

  def linear_assigned(*nodes, more: false, viewer: VIEWER_ID)
    page = { nodes:, pageInfo: { endCursor: more ? "issues-page-2" : nil, hasNextPage: more } }

    linear_json(data: { viewer: { assignedIssues: page, id: viewer } })
  end

  def linear_change(from, to, at:)
    { createdAt: at.utc.iso8601(3), fromState: from && { type: from }, toState: to && { type: to } }
  end

  def linear_comment(id, body: "Looks good", author: "aaron", at: Time.now - 600)
    { body:, createdAt: at.utc.iso8601(3), id:, user: author && { displayName: author },
      url: "https://linear.app/aaronmallen/issue/abc-1/sync-my-issues#comment-#{id}" }
  end

  def linear_errors(code, message = "Linear said no", status: 400)
    linear_json(errors: [{ extensions: { code: }, message: }]).merge(status:)
  end

  def linear_history(*nodes, more: false)
    { nodes:, pageInfo: { endCursor: more ? "history-#{nodes.last&.dig(:createdAt)}" : nil, hasNextPage: more } }
  end

  def linear_issue(id, key: "ABC-1", state: "unstarted", assignee: VIEWER_ID, **fields)
    { assignee: assignee && { id: assignee }, children: linear_related, comments: { nodes: [] },
      description: "Keep them in step", id:, identifier: key, inverseRelations: linear_related, labels: { nodes: [] },
      parent: nil, relations: linear_related, state: { type: state }, title: "Sync my issues", trashed: nil,
      url: "https://linear.app/aaronmallen/issue/#{key.downcase}/sync-my-issues" }.merge(fields)
  end

  def linear_issues(*nodes, viewer: VIEWER_ID) = linear_json(data: { issues: { nodes: }, viewer: { id: viewer } })

  def linear_json(body) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

  def linear_related(*nodes, more: false) = { nodes:, pageInfo: { hasNextPage: more } }

  def linear_request(query, key: nil, **variables)
    a_request(:post, URL).with do |request|
      body = JSON.parse(request.body)
      (key.nil? || request.headers["Authorization"] == key) && body["query"].include?(query) &&
        variables.all? { |name, value| body.dig("variables", name.to_s) == value }
    end
  end

  def stub_linear(query, *responses, key: nil, &block)
    stub = stub_request(:post, URL).with do |request|
      (key.nil? || request.headers["Authorization"] == key) && JSON.parse(request.body)["query"].include?(query)
    end
    block ? stub.to_return(&block) : stub.to_return(*responses)
  end
end

RSpec.configure do |config|
  config.include LinearGraphQL
end
