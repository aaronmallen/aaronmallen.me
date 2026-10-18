# frozen_string_literal: true

module Public
  module Actions
    module Search
      class Index < Action
        GROUP = Blog::Structs::Page.new(number: 1, size: 3)
        KINDS = Blog::Types::PublicSearchKind.values
        LATEST = 3

        include Deps[
          claim_search_attempt: "search.operations.claim_search_attempt",
          honeybadger: "honeybadger.agent",
          post_queries: "posts.repos.post_queries",
          project_queries: "projects.repos.project_queries",
          search_queries: "search.repos.public_search_queries",
        ]

        share_with_caches

        def handle(request, response)
          text = Blog::Types::TrimmedText[request.params[:q]]
          kind = Blog::Types::PublicSearchKindParam[request.params[:kind]]
          return limit(response, text, kind) if throttled?(request, text)

          results = results(response, text, kind, requested_page(request, response))

          { query: text, kind:, **results, **ways(results) }.each { |key, value| response[key] = value }
        end

        private

        def boards(groups)
          ids = groups["project"]&.rows.to_a.map(&:source_id)
          ids.empty? ? [] : project_queries.public_boards(ids).map(&:id)
        end

        def grouped(text, counts) = KINDS.select { counts[it] }.to_h { [it, search(text, it, GROUP)] }

        def limit(response, text, kind)
          response.status = :too_many_requests
          { query: text, kind:, limited: true }.each { |key, value| response[key] = value }
        end

        def results(response, text, kind, page)
          counts = search_queries.counts(text:)
          groups = kind ? { kind => search(text, kind, page) } : grouped(text, counts)
          not_found(response) if groups.values.any?(&:past_end?)

          { counts:, groups:, boards: boards(groups), failed: false }
        rescue Sequel::DatabaseError => e
          honeybadger.notify(e)
          response.status = :service_unavailable
          { counts: {}, groups: {}, boards: [], failed: true }
        end

        def search(text, kind, page) = search_queries.search(text:, page:, kinds: [kind])

        def throttled?(request, text)
          !text.empty? && claim_search_attempt.call(read_visitor_address.call(request)).failure?
        rescue Sequel::DatabaseError => e
          honeybadger.notify(e)
          false
        end

        def ways(results)
          return { tags: [], latest: [] } if results[:failed] || results[:groups].values.any? { it.rows.any? }

          { tags: post_queries.published_tag_counts, latest: post_queries.published(LATEST) }
        end
      end
    end
  end
end
