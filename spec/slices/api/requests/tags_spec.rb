# frozen_string_literal: true

RSpec.describe "API tags", type: :request do
  def mail_tagged(name) = create(:message).tap { Mail::Slice["repos.message_tag_mutations"].add(it.id, name) }

  def status = last_response.status

  def tag_queries = Tags::Slice["repos.tag_queries"]

  describe "GET /api/v1/tags" do
    it "lists the scope's tags by name with how many records carry each" do
      create(:post, tags: %w[ruby])
      create(:tag, :private, name: "health")

      expect([call_api(:get, "/tags", { scope: "public" }).fetch("tags").map { it.values_at("name", "count") }, status])
        .to eq([[["ruby", 1]], 200])
    end

    it "keeps only the tags whose name holds the query" do
      create(:tag, name: "ruby")
      create(:tag, name: "rails")

      expect(call_api(:get, "/tags", { scope: "public", query: "rub" }).values_at("count", "partial")).to eq([1, false])
    end

    it "answers the same JSON as list_tags" do
      create(:post, tags: %w[ruby])

      expect(call_api(:get, "/tags", { scope: "public" })).to eq(mcp_answer("list_tags", scope: "public"))
    end

    describe "without the mail scope" do
      def private_tags = call_api(:get, "/tags", { scope: "private" }, token: api_token(%w[read])).fetch("tags")

      it "leaves mail threads out of a tag's count and kinds" do
        create(:task, tags: %w[billing])
        mail_tagged("billing")

        expect(private_tags.map { it.values_at("name", "count", "by_kind") })
          .to eq([["billing", 1, { "tasks" => 1 }]])
      end

      it "leaves out a tag only mail threads carry", :aggregate_failures do
        create(:task, tags: %w[chores])
        mail_tagged("billing")

        expect(private_tags.map { it.fetch("name") }).to eq(%w[chores])
        expect(call_api(:get, "/tags", { scope: "private" }, token: api_token(%w[read])).fetch("count")).to eq(1)
      end

      it "keeps a tag nothing carries" do
        create(:tag, :private, name: "chores")

        expect(private_tags.map { it.fetch("name") }).to eq(%w[chores])
      end
    end

    it "counts mail threads with the mail scope" do
      mail_tagged("billing")

      expect(call_api(:get, "/tags", { scope: "private" }).fetch("tags").map { it.values_at("name", "by_kind") })
        .to eq([["billing", { "messages" => 1 }]])
    end

    it "refuses a request with no scope with a 422" do
      call_api(:get, "/tags")

      expect(status).to eq(422)
    end
  end

  describe "POST /api/v1/tags" do
    it "adds the tag to its scope with a 201" do
      added = call_api(:post, "/tags", JSON.generate(scope: "private", name: "health", color: "mk-blue"))

      expect([added.values_at("name", "color"), status]).to eq([%w[health mk-blue], 201])
    end

    it "refuses a name another tag holds with a 422" do
      create(:tag, name: "ruby")
      call_api(:post, "/tags", JSON.generate(scope: "public", name: "ruby"))

      expect([JSON.parse(last_response.body).fetch("errors"), status])
        .to eq([{ "name" => ["another tag already holds that name"] }, 422])
    end
  end

  describe "PATCH /api/v1/tags/:scope/:id" do
    it "renames the tag and keeps its colour" do
      tag = create(:tag, name: "ruby", color: "mk-blue")

      expect(call_api(:patch, "/tags/public/#{tag.id}", JSON.generate(name: "rails")).values_at("name", "color"))
        .to eq(%w[rails mk-blue])
    end

    it "answers a tag from the other scope with a 404" do
      tag = create(:tag, :private)
      call_api(:patch, "/tags/public/#{tag.id}", JSON.generate(name: "rails"))

      expect(status).to eq(404)
    end

    it "refuses a tag only mail threads carry without the mail scope, naming mail", :aggregate_failures do
      mail_tagged("billing")
      id = tag_queries.all_in("private").first.id
      call_api(:patch, "/tags/private/#{id}", { name: "invoices" }, token: api_token(%w[write]))

      expect([last_response.body, status]).to match([include("mail scope"), 422])
      expect(tag_queries.find_in("private", id)).to have_attributes(name: "billing")
    end

    it "renames a tag mail threads and other records carry without the mail scope" do
      mail_tagged("billing")
      create(:task, tags: %w[billing])
      id = tag_queries.all_in("private").first.id
      call_api(:patch, "/tags/private/#{id}", { name: "invoices" }, token: api_token(%w[write]))

      expect([status, tag_queries.find_in("private", id).name]).to eq([200, "invoices"])
    end

    it "renames a tag only mail threads carry with the mail scope" do
      mail_tagged("billing")
      id = tag_queries.all_in("private").first.id
      call_api(:patch, "/tags/private/#{id}", { name: "invoices" }, token: api_token(%w[write mail]))

      expect([status, tag_queries.find_in("private", id).name]).to eq([200, "invoices"])
    end
  end

  describe "DELETE /api/v1/tags/:scope/:id" do
    it "removes the tag for good", :aggregate_failures do
      tag = create(:tag)

      expect([call_api(:delete, "/tags/public/#{tag.id}"), status]).to eq([{ "id" => tag.id, "removed" => true }, 200])
      expect(tag_queries.find_in("public", tag.id)).to be_nil
    end

    it "refuses a tag a mail thread carries without the mail scope, naming mail", :aggregate_failures do
      mail_tagged("billing")
      id = tag_queries.all_in("private").first.id
      call_api(:delete, "/tags/private/#{id}", nil, token: api_token(%w[delete]))

      expect([last_response.body, status]).to match([include("mail scope"), 422])
      expect(tag_queries.find_in("private", id)).not_to be_nil
    end

    it "removes a tag a mail thread carries with the mail scope" do
      mail_tagged("billing")
      id = tag_queries.all_in("private").first.id
      call_api(:delete, "/tags/private/#{id}", nil, token: api_token(%w[delete mail]))

      expect([status, tag_queries.find_in("private", id)]).to eq([200, nil])
    end

    it "answers an unknown ID with a 404" do
      expect([call_api(:delete, "/tags/public/999999").fetch("message"),
              status]).to eq(["no tag has the ID 999999", 404])
    end
  end
end
