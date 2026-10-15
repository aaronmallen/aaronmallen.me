# frozen_string_literal: true

require "securerandom"
require "sidekiq/api"

RSpec.describe "Dead jobs on the attention list", :frozen_clock, type: :request do
  let(:dead_set) { Spec::FakeJobSet.new("dead") }
  let(:retry_set) { Spec::FakeJobSet.new("retry") }

  before do
    allow(Sidekiq::DeadSet).to receive(:new).and_return(dead_set)
    allow(Sidekiq::RetrySet).to receive(:new).and_return(retry_set)
  end

  def api_read = call_api(:get, "/attention")

  def card
    sign_in_to_admin
    get "/admin"
    Capybara.string(last_response.body).find("section.card[data-attention]")
  end

  def job(name, args: [], error: "boom", jid: SecureRandom.hex(12))
    {
      "class" => name, "args" => args, "jid" => jid, "queue" => "default", "retry" => 3,
      "error_class" => "RuntimeError", "error_message" => error,
    }
  end

  def kill(name, at:, **) = dead_set.add(at, job(name, **))

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
      expected = {
        "name" => "Social::Jobs::SendWebmention", "died_at" => died_at.utc.iso8601,
        "error" => { "untrusted" => true, "text" => error },
      }

      expect(mcp_answer("list_attention").fetch("dead_jobs")).to eq([expected])
    end

    it "answers the MCP tool with the JSON the endpoint gives" do
      expect(trusted(mcp_answer("list_attention"))).to eq(api_read)
    end
  end

  describe "acting on a job from the card" do
    let(:jid) { SecureRandom.hex(12) }

    before { kill("Social::Jobs::SendWebmention", at: Time.now - 60, jid:) }

    def submit(label)
      action = card.find("form:has(button[aria-label='#{label}'])")[:action]
      post action, _csrf_token: admin_csrf_token
    end

    it "queues the job again and takes it off the card when retried", :aggregate_failures do
      submit("Retry")

      expect(Sidekiq::Queues["default"].map { it["jid"] }).to eq([jid])
      expect(page_has_card?).to be(false)
    end

    it "deletes the job and takes it off the card when discarded", :aggregate_failures do
      submit("Discard")

      expect([dead_set.size, Sidekiq::Queues["default"]]).to eq([0, []])
      expect(page_has_card?).to be(false)
    end

    it "draws Discard with the trash icon every other delete uses" do
      expect(card.find("button[aria-label='Discard']")).to have_css("i.fa-regular.fa-trash-can", visible: :all)
    end

    it "asks before it discards" do
      expect(card.find("form:has(button[aria-label='Discard'])")["data-confirm"])
        .to include("Social::Jobs::SendWebmention")
    end

    %w[discard retry].each do |verb|
      it "answers a #{verb} of a job that is gone with not found" do
        sign_in_to_admin
        post "/admin/attention/dead-jobs/#{SecureRandom.hex(12)}/#{verb}", _csrf_token: admin_csrf_token

        expect(last_response.status).to eq(404)
      end
    end
  end

  it "lists the newest death first" do
    kill("Posts::Jobs::Older", at: Time.now - 7200)
    kill("Posts::Jobs::Newer", at: Time.now - 60)

    expect(titles).to eq(["Posts::Jobs::Newer", "Posts::Jobs::Older"])
  end

  it "leaves a job that is still retrying off the card" do
    retry_set.add(Time.now + 60, job("Posts::Jobs::Retrying"))

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
    allow(Sidekiq::DeadSet).to receive(:new).and_raise(RedisClient::CannotConnectError)

    expect(api_read.fetch("dead_jobs")).to eq([])
  end

  def titles = card.all(".li-title").map(&:text)
end
