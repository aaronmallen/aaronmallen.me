# frozen_string_literal: true

RSpec.describe "API page and ID bounds", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }

  def largest = Blog::Constants::INTEGER_MAX

  def read(path, query)
    get path, query, headers
    JSON.parse(last_response.body)
  end

  def send_ids(path, ids)
    post path, JSON.generate(ids:), headers.merge("CONTENT_TYPE" => "application/json")
    JSON.parse(last_response.body)
  end

  def status = last_response.status

  describe "paged endpoints" do
    {
      "/api/v1/tasks" => { key: "tasks", query: -> { {} } },
      "/api/v1/decisions" => { key: "decisions", query: -> { {} } },
      "/api/v1/sprints" => { key: "sprints", query: -> { {} } },
      "/api/v1/search" => { key: "results", query: -> { { query: "plumber" } } },
      "/api/v1/saved_views/:id/records" => { key: "records", query: -> { {} } },
    }.each do |route, spec|
      describe route do
        let(:path) { route.sub(":id", create(:saved_view, screen: "tasks", filters: { filter: "next" }).id.to_s) }
        let(:query) { instance_exec(&spec.fetch(:query)) }

        before do
          create(:task, title: "Call the plumber")
          create(:sprint, sprint_date: Blog::TimeZone.today)
        end

        it "refuses a page past the largest with 422 and says why under page" do
          answer = read(path, query.merge(page: (largest + 1).to_s))

          expect([status, answer.fetch("errors").keys]).to eq([422, %w[page]])
        end

        it "answers a distant page with no rows" do
          answer = read(path, query.merge(page: largest.to_s))

          expect([status, answer.fetch(spec.fetch(:key))]).to eq([200, []])
        end
      end
    end
  end

  describe "paged tools that share an endpoint" do
    {
      "list_decisions" => -> { {} },
      "search" => -> { { query: "plumber" } },
      "read_saved_view" => -> { { id: create(:saved_view, screen: "tasks", filters: { filter: "next" }).id } },
    }.each do |name, arguments|
      it "#{name} refuses a page past the largest" do
        expect(mcp_call(name, **instance_exec(&arguments), page: largest + 1).fetch("isError")).to be(true)
      end
    end
  end

  describe "bulk endpoints" do
    %w[
      /api/v1/tasks/bulk/complete
      /api/v1/posts/bulk/delete
      /api/v1/messages/bulk/read
      /api/v1/webmentions/bulk/approve
    ].each do |path|
      describe path do
        [0, 2**31].each do |id|
          it "refuses the ID #{id} with 422 and a list of reasons under ids" do
            answer = send_ids(path, [id])

            expect([status, answer.fetch("errors").keys, answer.dig("errors", "ids")])
              .to match([422, %w[ids], all(be_a(String))])
          end
        end
      end
    end
  end
end
