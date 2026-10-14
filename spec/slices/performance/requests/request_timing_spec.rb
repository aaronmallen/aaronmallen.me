# frozen_string_literal: true

RSpec.describe "Timing a request", type: :request do
  let(:json) { { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" } }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def rows = Performance::Slice["db.rom"].relations[:performance_requests].to_a

  before { serve_like_puma }

  context "when a visitor reads a post" do
    before do
      create(:post, :published, slug: "hello")
      get "/writing/hello"
    end

    it "writes nothing before the reply goes out" do
      expect(rows).to be_empty
    end

    it "stores the route pattern, verb and status once the reply goes out" do
      reply

      expect(rows).to contain_exactly(include(route: "/writing/:slug", verb: "GET", status: 200))
    end

    it "stores the time and the queries it took" do
      reply

      expect(rows.first).to include(duration: be_positive, query_count: be_positive, query_time: be >= 0)
    end
  end

  it "stores the admin route the owner opens" do
    sign_in_to_admin
    replies.clear
    get "/admin/tasks"
    reply

    expect(rows).to contain_exactly(include(route: "/admin/tasks", verb: "GET", status: 200))
  end

  it "stores the API route an agent reads" do
    get "/api/v1/attention", {}, json.merge("HTTP_AUTHORIZATION" => "Bearer #{api_token}")
    reply

    expect(rows).to contain_exactly(include(route: "/api/v1/attention", verb: "GET", status: 200))
  end

  it "stores the MCP route a client posts to" do
    post "/mcp", JSON.generate(jsonrpc: "2.0", id: 1, method: "tools/list"), json
    reply

    expect(rows).to contain_exactly(include(route: "/mcp", verb: "POST"))
  end

  it "stores no route for a path nothing serves" do
    get "/nothing/here"
    reply

    expect(rows).to contain_exactly(include(route: nil, status: 404))
  end

  context "when the row fails to write" do
    let(:crash) { Class.new(StandardError) }

    before do
      error = crash
      repo = Object.new.tap { |stub| stub.define_singleton_method(:record_request) { |**| raise error } }
      replace_component("repos.timing_mutations", repo)
      allow(Hanami.app["logger"]).to receive(:error)
      get "/"
    end

    it "still answers the request" do
      expect(last_response).to be_ok
    end

    it "swallows the failure after the reply" do
      expect { reply }.not_to raise_error
    end

    it "logs that the row was lost" do
      reply

      lost = Performance::Operations::RecordTiming::LOST

      expect(Hanami.app["logger"]).to have_received(:error).with(lost, error: crash.name)
    end
  end

  it "writes no row when the server offers no after reply hook" do
    env Blog::RequestTimer::AFTER_REPLY, nil
    get "/"

    expect(rows).to be_empty
  end
end
