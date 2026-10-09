# frozen_string_literal: true

require "time"

module Record
  module GitHub
    class Client
      include Paging
      include Issues
      include PullRequests

      Error = Transport::Error
      RateLimited = Transport::RateLimited

      module Queries
        AFFILIATIONS = "[OWNER, COLLABORATOR, ORGANIZATION_MEMBER]"
        BRANCH_PAGE_SIZE = 10
        COMMIT_PAGE_SIZE = 100
        REPOSITORY_PAGE_SIZE = 100

        COMMIT_FIELDS = <<~GRAPHQL
          pageInfo { hasNextPage endCursor }
          nodes { oid message authoredDate committedDate additions deletions }
        GRAPHQL

        COMMITS = <<~GRAPHQL.freeze
          query($owner: String!, $name: String!, $author: ID!, $since: GitTimestamp, $until: GitTimestamp,
                $cursor: String) {
            repository(owner: $owner, name: $name) {
              createdAt
              defaultBranchRef { name }
              refs(refPrefix: "refs/heads/", first: #{BRANCH_PAGE_SIZE}, after: $cursor) {
                pageInfo { hasNextPage endCursor }
                nodes {
                  name
                  target {
                    ... on Commit {
                      history(first: #{COMMIT_PAGE_SIZE}, author: {id: $author}, since: $since, until: $until) {
                        #{COMMIT_FIELDS}
                      }
                    }
                  }
                }
              }
            }
            rateLimit { limit remaining resetAt }
          }
        GRAPHQL

        REPOSITORIES = <<~GRAPHQL.freeze
          query($cursor: String) {
            viewer {
              repositories(
                first: #{REPOSITORY_PAGE_SIZE}
                after: $cursor
                affiliations: #{AFFILIATIONS}
                ownerAffiliations: #{AFFILIATIONS}
                orderBy: {field: PUSHED_AT, direction: DESC}
              ) {
                pageInfo { hasNextPage endCursor }
                nodes { nameWithOwner pushedAt viewerPermission }
              }
            }
            rateLimit { limit remaining resetAt }
          }
        GRAPHQL

        VIEWER = <<~GRAPHQL
          query {
            viewer { id }
            rateLimit { limit remaining resetAt }
          }
        GRAPHQL
      end
      private_constant :Queries

      PUSH_PERMISSIONS = %w[ADMIN MAINTAIN WRITE].freeze

      def initialize(transport:)
        @transport = transport
        @viewer = nil
      end

      def commits(repo, since: nil, before: nil)
        owner, name = repo.split("/", 2)

        branches(before:, name:, owner:, since:)
      end

      def configured? = transport.configured?

      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      def latest_release(repo) = transport.get("/repos/#{repo}/releases/latest")&.fetch("tag_name", nil)

      def rate_limit_remaining = transport.rate_limit_remaining

      def rate_limit_reset_at = transport.rate_limit_reset_at

      def repositories(pushed_since: nil)
        listing = walk do |cursor, found|
          page = repository_page(cursor)
          nodes = repository_nodes(page)
          recent = pushed_since ? nodes.take_while { pushed_since?(it, pushed_since) } : nodes
          found.concat(recent.select { pushable?(it) }.map { it.fetch("nameWithOwner") })
          page if recent.size == nodes.size
        end

        listing.items
      end

      def repository_names
        walk do |cursor, found|
          page = repository_page(cursor)
          found.concat(repository_nodes(page).select { pushable?(it) }.map { it.fetch("nameWithOwner") })
          page
        end
      end

      def stars(repo)
        body = transport.get("/repos/#{repo}")

        body && body["stargazers_count"].to_i
      end

      private

      attr_reader :transport

      def authored(document, before:, since:, **variables)
        transport.query(document, author: viewer_id, since: stamp(since), until: stamp(before), **variables)
      end

      def branch(node, repository)
        page = node.dig("target", "history")
        found = page ? page.fetch("nodes").map { commit_attributes(it) } : Blog::Constants::EMPTY_ARRAY
        made = repository["createdAt"]

        { commits: found, complete: read_to_end?(page), created_at: made && Time.iso8601(made),
          default: node.fetch("name") == repository.dig("defaultBranchRef", "name"), name: node.fetch("name") }
      end

      def branches(**scope)
        walk do |cursor, found|
          repository = authored(Queries::COMMITS, cursor:, **scope)&.dig("repository")
          refs = repository&.dig("refs")
          refs&.fetch("nodes")&.each { found << branch(it, repository) }
          refs
        end
      end

      def commit_attributes(commit)
        {
          additions: commit["additions"].to_i,
          authored_at: Time.iso8601(commit.fetch("authoredDate")),
          committed_at: Time.iso8601(commit.fetch("committedDate")),
          deletions: commit["deletions"].to_i,
          message: commit["message"].to_s.strip,
          sha: commit.fetch("oid"),
        }
      end

      def pushable?(repo) = PUSH_PERMISSIONS.include?(repo["viewerPermission"])

      def pushed_since?(repo, since)
        pushed_at = repo["pushedAt"]
        !pushed_at.nil? && Time.iso8601(pushed_at) >= since
      end

      def read_to_end?(page) = !page.nil? && !more?(page)

      def repository_nodes(page) = page ? page.fetch("nodes") : Blog::Constants::EMPTY_ARRAY

      def repository_page(cursor) = transport.query(Queries::REPOSITORIES, cursor:)&.dig("viewer", "repositories")

      def stamp(time) = time&.utc&.iso8601

      def viewer_id
        token = transport.token
        @viewer = { token => transport.query(Queries::VIEWER)&.dig("viewer", "id") } unless @viewer&.[](token)
        @viewer[token] || raise(Error, "GitHub sent no viewer id")
      end
    end
  end
end
