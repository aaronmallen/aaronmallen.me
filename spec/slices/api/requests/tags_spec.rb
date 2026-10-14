# frozen_string_literal: true

RSpec.describe "API tags", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/tags#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def status = last_response.status

  def tag_queries = Tags::Slice["repos.tag_queries"]

  describe "GET /api/v1/tags" do
    it "lists the scope's tags by name with how many records carry each" do
      create(:post, tags: %w[ruby])
      create(:tag, :private, name: "health")

      expect([call_api(:get, "", { scope: "public" }).fetch("tags").map { it.values_at("name", "count") }, status])
        .to eq([[["ruby", 1]], 200])
    end

    it "keeps only the tags whose name holds the query" do
      create(:tag, name: "ruby")
      create(:tag, name: "rails")

      expect(call_api(:get, "", { scope: "public", query: "rub" }).values_at("count", "partial")).to eq([1, false])
    end

    it "answers the same JSON as list_tags" do
      create(:post, tags: %w[ruby])

      expect(call_api(:get, "", { scope: "public" })).to eq(mcp_answer("list_tags", scope: "public"))
    end

    it "refuses a request with no scope with a 422" do
      call_api(:get, "")

      expect(status).to eq(422)
    end
  end

  describe "POST /api/v1/tags" do
    it "adds the tag to its scope with a 201" do
      added = call_api(:post, "", JSON.generate(scope: "private", name: "health", color: "mk-blue"))

      expect([added.values_at("name", "color"), status]).to eq([%w[health mk-blue], 201])
    end

    it "refuses a name another tag holds with a 422" do
      create(:tag, name: "ruby")
      call_api(:post, "", JSON.generate(scope: "public", name: "ruby"))

      expect([JSON.parse(last_response.body).fetch("errors"), status])
        .to eq([{ "name" => ["another tag already holds that name"] }, 422])
    end
  end

  describe "PATCH /api/v1/tags/:scope/:id" do
    it "renames the tag and keeps its colour" do
      tag = create(:tag, name: "ruby", color: "mk-blue")

      expect(call_api(:patch, "/public/#{tag.id}", JSON.generate(name: "rails")).values_at("name", "color"))
        .to eq(%w[rails mk-blue])
    end

    it "answers a tag from the other scope with a 404" do
      tag = create(:tag, :private)
      call_api(:patch, "/public/#{tag.id}", JSON.generate(name: "rails"))

      expect(status).to eq(404)
    end
  end

  describe "DELETE /api/v1/tags/:scope/:id" do
    it "removes the tag for good", :aggregate_failures do
      tag = create(:tag)

      expect([call_api(:delete, "/public/#{tag.id}"), status]).to eq([{ "id" => tag.id, "removed" => true }, 200])
      expect(tag_queries.find_in("public", tag.id)).to be_nil
    end

    it "answers an unknown ID with a 404" do
      expect([call_api(:delete, "/public/999999").fetch("message"), status]).to eq(["no tag has the ID 999999", 404])
    end
  end
end
