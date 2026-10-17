# frozen_string_literal: true

RSpec.describe "API bulk webmention actions", type: :request do
  def act(name, ids) = call_api(:post, "/webmentions/bulk/#{name}", JSON.generate(ids:))

  def bare(answer) = answer.fetch("webmentions").map { it.except("id", "source_url") }

  def fields(mention, status)
    {
      "id" => mention.id,
      "post_id" => mention.post_id,
      "type" => mention.type,
      "status" => status,
      "source_url" => mention.source_url,
      "author_name" => mention.author_name,
      "author_url" => mention.author_url,
      "excerpt" => mention.excerpt,
      "spam_reason" => nil,
      "received_at" => mention.received_at.utc.iso8601,
    }
  end

  def gone_id = create(:webmention).id.tap { Social::Slice["relations.webmentions"].by_pk(it).delete }

  def ids(mentions) = mentions.map(&:id)

  def mentions(count) = Array.new(count) { create(:webmention) }

  def refusal(message) = { "error" => "invalid", "message" => message, "errors" => { "ids" => [message] } }

  def status_of(mention) = Social::Slice["relations.webmentions"].by_pk(mention.id).one.fetch(:status)

  def twins
    shared = { post_id: create(:post).id, author_name: "Ada", author_url: "https://ada.example", excerpt: "Hi" }

    Array.new(2) { create(:webmention, **shared, received_at: Time.utc(2026, 3, 1, 12)) }
  end

  {
    "approve" => "approved",
    "ignore" => "ignored",
    "spam" => "spam",
  }.each do |name, changed|
    describe "POST /api/v1/webmentions/bulk/#{name}" do
      let!(:picked) { mentions(2) }
      let!(:left) { create(:webmention) }

      it "changes the webmentions it names and answers them" do
        answer = act(name, ids(picked))

        expect([answer.fetch("webmentions").map { it.values_at("id", "status") }, status])
          .to eq([ids(picked).map { [it, changed] }, 200])
      end

      it "leaves the rest alone" do
        act(name, ids(picked))

        expect(status_of(left)).to eq("pending")
      end

      it "changes none when one ID is gone and names it" do
        gone = gone_id

        expect([act(name, [*ids(picked), gone]), status, picked.map { status_of(it) }])
          .to eq([refusal("no webmention has the ID #{gone}"), 422, %w[pending pending]])
      end
    end
  end

  describe "POST /api/v1/webmentions/bulk/approve on spam" do
    it "clears the reason given for spam" do
      spam = create(:webmention, :spam, spam_reason: "link farm")

      expect(act("approve", [spam.id]).fetch("webmentions").map { it.fetch("spam_reason") }).to eq([nil])
    end
  end

  describe "the answer" do
    it "gives each webmention's fields" do
      mention = create(:webmention, received_at: Time.utc(2026, 3, 1, 12))

      expect(act("approve", [mention.id]).fetch("webmentions")).to eq([fields(mention, "approved")])
    end
  end

  describe "the list of IDs" do
    it "acts on a repeated ID once" do
      mention = create(:webmention)

      expect(act("approve", [mention.id, mention.id]).fetch("webmentions").map { it.fetch("id") }).to eq([mention.id])
    end

    it "refuses an empty list" do
      expect([act("approve", []).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses more than 100 IDs" do
      expect([act("approve", (1..101).to_a).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses an ID that is not a number" do
      expect([act("approve", ["one"]).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses a request with no IDs" do
      expect(call_api(:post, "/webmentions/bulk/approve", "{}").fetch("errors")).to eq("ids" => ["ids is missing"])
    end
  end

  it "answers a failure it did not expect with a 500 that names the webmention" do
    failing = instance_double(Social::Operations::ActOnWebmentions, call: Failure([:record, 7, :unexpected]))
    replace_component("social.operations.act_on_webmentions", failing)

    expect([act("approve", [7]), status])
      .to eq([{ "error" => "failed", "message" => "could not change webmention 7" }, 500])
  end

  describe "the MCP tools" do
    {
      "approve" => "approve_webmentions",
      "ignore" => "ignore_webmentions",
      "spam" => "mark_webmentions_spam",
    }.each do |name, tool|
      it "#{name} as #{tool} does" do
        first, last = twins

        expect(bare(trusted(mcp_answer(tool, ids: [last.id])))).to eq(bare(act(name, [first.id])))
      end
    end

    it "refuse a gone ID with the message the endpoint gives" do
      gone = gone_id
      refused = act("approve", [gone])

      expect(mcp_text("approve_webmentions", ids: [gone])).to eq(refused.fetch("message"))
    end
  end
end
