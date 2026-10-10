# frozen_string_literal: true

require "securerandom"
require "sidekiq/api"

RSpec.describe "Dead jobs on the attention list", :frozen_clock, type: :request do
  let(:dead_set) { Sidekiq::JobSet.new("dead-spec-#{SecureRandom.hex(8)}") }
  let(:retry_set) { Sidekiq::JobSet.new("retry") }
  let(:retrying_jid) { SecureRandom.hex(12) }

  before do
    Hanami.app.start(:sidekiq)
    replace_component("sidekiq.dead_set", -> { dead_set })
  end

  after do
    dead_set.clear
    retry_set.find_job(retrying_jid)&.delete
  end

  def api_read
    token = API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)
    get "/api/v1/attention", {}, { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    JSON.parse(last_response.body)
  end

  def card
    sign_in_to_admin
    get "/admin"
    Capybara.string(last_response.body).find("section.card[data-attention]")
  end

  def job(name, args: [], error: "boom", jid: SecureRandom.hex(12))
    Sidekiq.dump_json(
      "class" => name, "args" => args, "jid" => jid, "queue" => "default", "retry" => 3,
      "error_class" => "RuntimeError", "error_message" => error,
    )
  end

  def kill(name, at:, **)
    Sidekiq.redis { it.zadd(dead_set.name, at.to_f.to_s, job(name, **)) }
  end

  def page_has_card?
    sign_in_to_admin
    get "/admin"
    Capybara.string(last_response.body).has_css?("section.card[data-attention]")
  end

  describe "a job that died" do
    let(:died_at) { Time.now - 3600 }
    let(:error) { "RuntimeError: the target refused it" }

    before { kill("Social::Jobs::SendWebmention", at: died_at, error: "the target refused it") }

    it "shows on the card with its name, when it died and its error", :aggregate_failures do
      row = card.find(".li", text: "Social::Jobs::SendWebmention")

      expect(row.find(".li-sub").text).to end_with("· RuntimeError: the target refused it")
      expect(Time.iso8601(row.find(".li-sub time")[:datetime])).to eq(died_at.floor)
    end

    it "returns it from list_attention" do
      expected = { "name" => "Social::Jobs::SendWebmention", "died_at" => died_at.utc.iso8601, "error" => error }

      expect(mcp_answer("list_attention").fetch("dead_jobs")).to eq([expected])
    end

    it "answers the MCP tool with the JSON the endpoint gives" do
      expect(mcp_answer("list_attention")).to eq(api_read)
    end
  end

  it "lists the newest death first" do
    kill("Posts::Jobs::Older", at: Time.now - 7200)
    kill("Posts::Jobs::Newer", at: Time.now - 60)

    expect(titles).to eq(["Posts::Jobs::Newer", "Posts::Jobs::Older"])
  end

  it "leaves a job that is still retrying off the card" do
    Sidekiq.redis { it.zadd(retry_set.name, (Time.now + 60).to_f.to_s, job("Posts::Jobs::Retrying", jid: retrying_jid)) }

    expect(page_has_card?).to be(false)
  end

  describe "a commit backfill whose sync failure the card shows" do
    before do
      Record::Slice["repos.sync_state_mutations"]
        .record_failure(Blog::Types::SyncName["commits"], :github_failed, repo: "aaronmallen/one")
      clock = Time.now.utc.iso8601
      kill(Record::Jobs::BackfillRepoCommits.name, at: Time.now - 60, args: ["aaronmallen/one", clock])
      kill(Record::Jobs::BackfillRepoCommits.name, at: Time.now - 120, args: ["aaronmallen/two", clock])
    end

    it "shows the failure once, and the dead backfill for another repository" do
      found = card

      expect([found.all(".sync-failure").size, found.all(".li-title").map(&:text)])
        .to eq([1, [Record::Jobs::BackfillRepoCommits.name]])
    end

    it "still returns both from list_attention" do
      expect(mcp_answer("list_attention").fetch("dead_jobs").size).to eq(2)
    end
  end

  it "lists no dead jobs while Redis is down" do
    replace_component("sidekiq.dead_set", -> { raise RedisClient::CannotConnectError })

    expect(api_read.fetch("dead_jobs")).to eq([])
  end

  def titles = card.all(".li-title").map(&:text)
end
