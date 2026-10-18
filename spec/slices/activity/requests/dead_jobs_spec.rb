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

    it "posts to the jobs tab's dead set and comes back to Today", :aggregate_failures do
      forms = card.all("form:has(button[aria-label='Retry']), form:has(button[aria-label='Discard'])")

      expect(forms.map { it[:action] }).to eq(%w[retry discard].map { "/admin/settings/jobs/dead/#{jid}/#{it}" })
      expect(forms.map { it.find("input[name=return_to]", visible: :all).value }.uniq).to eq(["/admin"])
    end

    it "opens the jobs tab's menu for the row, which copies its error", :aggregate_failures do
      menu = card.find(".li", text: "Social::Jobs::SendWebmention")["data-menu"]
      get menu, return_to: "/admin"

      expect(menu).to eq("/admin/settings/jobs/dead/#{jid}/menu")
      expect(menu_items).to eq(["Retry now", "Copy error", "Discard"])
      expect(page.find("[data-copy]", visible: :all)["data-copy"]).to eq("RuntimeError: boom")
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
      sync_state_mutations.record_failure(Blog::Types::SyncName["commits"], :github_failed, repo: "aaronmallen/one")
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

  describe "more dead jobs than the card holds" do
    before { 7.times { kill("Posts::Jobs::Job#{it}", at: Time.now - (it * 60)) } }

    it "shows the newest five and links to the rest", :aggregate_failures do
      found = card
      line = found.find("a.today-line", text: "Dead jobs")

      expect(found.all(".li-title").map(&:text)).to eq((0..4).map { "Posts::Jobs::Job#{it}" })
      expect([line[:href], line.text]).to eq(["/admin/settings/jobs?set=dead#jobs-dead", "Dead jobs2 more →"])
    end

    it "returns the newest five from list_attention with the count of all", :aggregate_failures do
      answer = api_read

      expect(answer.fetch("dead_jobs").map { it.fetch("name") }).to eq((0..4).map { "Posts::Jobs::Job#{it}" })
      expect(answer.fetch("dead_job_count")).to eq(7)
    end
  end

  it "lists no dead jobs while Redis is down" do
    allow(Sidekiq::DeadSet).to receive(:new).and_raise(RedisClient::CannotConnectError)

    expect(api_read.values_at("dead_jobs", "dead_job_count")).to eq([[], 0])
  end

  def titles = card.all(".li-title").map(&:text)
end
