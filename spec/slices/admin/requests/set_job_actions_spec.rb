# frozen_string_literal: true

require "securerandom"

RSpec.describe "Admin job set actions", :frozen_clock, type: :request do
  let(:sets) { %w[retry dead schedule].to_h { [it, Spec::FakeJobSet.new(it)] } }
  let(:jid) { SecureRandom.hex(12) }

  def act(set, verb, **) = admin_post("/admin/settings/jobs/#{set}/#{jid}/#{verb}", **)

  def confirm(scope, verb) = scope.find("form[action$='/#{verb}']")["data-confirm"]

  def drawer(set)
    get "/admin/settings/jobs?open=#{set}&jid=#{jid}"
    page.find("dialog#jobs-job .dialog-foot")
  end

  def gone_after_lookup(set)
    allow(set).to receive(:find_job).and_wrap_original do |original, found|
      original.call(found).tap { set.delete_by_value(set.name, it.value) }
    end
  end

  def inline_confirm(verb) = page.find("form[action$='/#{verb}'] button", visible: :all)["data-confirm-inline"]

  def jids(key) = sets.fetch(key).map(&:jid)

  def job(**) = { "class" => "Social::Jobs::CrossPost", "args" => [42], "jid" => jid, "queue" => "default", ** }

  def menu(set) = get("/admin/settings/jobs/#{set}/#{jid}/menu", return_to: "/admin/settings/jobs?set=#{set}")

  def queued = Sidekiq::Queues["default"]

  before do
    sign_in_to_admin
    allow(Sidekiq::RetrySet).to receive(:new).and_return(sets["retry"])
    allow(Sidekiq::DeadSet).to receive(:new).and_return(sets["dead"])
    allow(Sidekiq::ScheduledSet).to receive(:new).and_return(sets["schedule"])
    replace_component("sidekiq.set_jobs", ->(key, *, **) { sets.fetch(key).to_a })
  end

  describe "a scheduled job" do
    before { sets["schedule"].add(Time.now + 600, job) }

    it "runs now", :aggregate_failures do
      act("scheduled", "run")

      expect([jids("schedule"), queued.map { it["jid"] }]).to eq([[], [jid]])
      expect(toast).to eq("Queued to run now")
    end

    it "deletes", :aggregate_failures do
      act("scheduled", "delete")

      expect([jids("schedule"), queued]).to eq([[], []])
      expect(toast).to start_with("Job deleted")
    end

    it "answers 404 for an action its set lacks" do
      act("scheduled", "kill")

      expect(status).to eq(404)
    end
  end

  describe "a retry" do
    before { sets["retry"].add(Time.now + 60, job("retry_count" => 2)) }

    it "retries now with one try given back", :aggregate_failures do
      act("retries", "retry")

      expect([jids("retry"), queued.map { it.values_at("jid", "retry_count") }]).to eq([[], [[jid, 1]]])
      expect(toast).to eq("Job queued again")
    end

    it "kills it into the dead set", :aggregate_failures do
      act("retries", "kill")

      expect([jids("retry"), jids("dead"), queued]).to eq([[], [jid], []])
      expect(toast).to start_with("Sent to dead jobs")
    end

    it "deletes" do
      act("retries", "delete")

      expect([jids("retry"), queued]).to eq([[], []])
    end
  end

  describe "a dead job" do
    before { sets["dead"].add(Time.now - 60, job) }

    it "retries", :aggregate_failures do
      act("dead", "retry")

      expect([jids("dead"), queued.map { it["jid"] }]).to eq([[], [jid]])
      expect(toast).to eq("Job queued again")
    end

    it "discards", :aggregate_failures do
      act("dead", "discard")

      expect([jids("dead"), queued]).to eq([[], []])
      expect(toast).to eq("Job discarded")
    end
  end

  describe "landing" do
    before { sets["retry"].add(Time.now + 60, job) }

    it "keeps the set, page and drawer it was pressed on" do
      back = "/admin/settings/jobs?set=retries&page=2&open=retries&jid=#{jid}"
      act("retries", "retry", return_to: back)

      expect(last_response.location).to end_with("#{back}#jobs-retries")
    end

    it "lands on the set's card with no return_to" do
      act("retries", "retry")

      expect(last_response.location).to end_with("/admin/settings/jobs#jobs-retries")
    end

    it "says so when the job already left its set", :aggregate_failures do
      sets["retry"].delete_by_value("retry", sets["retry"].first.value)
      act("retries", "kill")

      expect([jids("dead"), toast]).to eq([[], "That job already left its list · nothing changed"])
    end

    it "says so when the job leaves its set between the lookup and the act", :aggregate_failures do
      gone_after_lookup(sets["retry"])
      act("retries", "kill")

      expect([jids("dead"), queued, toast]).to eq([[], [], "That job already left its list · nothing changed"])
    end

    it "changes nothing and says so when Redis is down" do
      allow(Sidekiq::RetrySet).to receive(:new).and_raise(RedisClient::CannotConnectError)
      act("retries", "delete")

      expect(toast).to start_with("Nothing changed")
    end
  end

  describe "the row" do
    before do
      sets["dead"].add(Time.now - 60, job)
      allow(Sidekiq::Stats).to receive(:new).and_return(Spec::FakeStats.new(dead_size: 1))
      get "/admin/settings/jobs"
    end

    it "carries its menu" do
      expect(page.find_by_id("jobs-dead").find(".li")["data-menu"]).to eq("/admin/settings/jobs/dead/#{jid}/menu")
    end

    it "retries from a button on hover, landing back on the page", :aggregate_failures do
      form = page.find_by_id("jobs-dead").find(".li .hov form")
      admin_post form[:action], return_to: form.find("input[name=return_to]", visible: :all).value

      expect(form).to have_button("Retry Social::Jobs::CrossPost now")
      expect([jids("dead"), queued.map { it["jid"] }]).to eq([[], [jid]])
      expect(last_response.location).to end_with("/admin/settings/jobs#jobs-dead")
    end
  end

  it "runs a scheduled job from a button on hover" do
    sets["schedule"].add(Time.now + 600, job)
    allow(Sidekiq::Stats).to receive(:new).and_return(Spec::FakeStats.new(scheduled_size: 1))
    get "/admin/settings/jobs"

    expect(page.find_by_id("jobs-scheduled").find(".li .hov")).to have_button("Run Social::Jobs::CrossPost now")
  end

  it "drops the rows and their buttons when Redis is down" do
    sets["dead"].add(Time.now - 60, job)
    allow(Sidekiq::Stats).to receive(:new).and_raise(RedisClient::CannotConnectError)
    get "/admin/settings/jobs"

    expect(page).to have_no_css("#jobs-dead").and have_no_css("form[action*='/admin/settings/jobs/dead/']")
  end

  describe "the menu" do
    it "offers run now and delete on a scheduled job, asking before delete", :aggregate_failures do
      sets["schedule"].add(Time.now + 600, job)
      menu("scheduled")

      expect(menu_items).to eq(["Run now", "Delete"])
      expect(inline_confirm("delete")).to eq("Click again · it won't run")
    end

    it "offers retry, kill and delete on a retry, asking before kill and delete", :aggregate_failures do
      sets["retry"].add(Time.now + 60, job)
      menu("retries")

      expect(menu_items).to eq(["Retry now", "Kill", "Delete"])
      expect([inline_confirm("retry"),
              inline_confirm("kill")]).to eq([nil, "Click again · moves to dead, no more tries"])
    end

    it "offers retry and discard on a dead job, asking before discard", :aggregate_failures do
      sets["dead"].add(Time.now - 60, job)
      menu("dead")

      expect(menu_items).to eq(["Retry now", "Discard"])
      expect(inline_confirm("discard")).to eq("Click again · gone for good")
    end

    it "brings each action back to the page it opened on" do
      sets["dead"].add(Time.now - 60, job)
      menu("dead")

      expect(page.all("input[name=return_to]",
                      visible: :all).map(&:value).uniq).to eq(["/admin/settings/jobs?set=dead"])
    end

    it "answers 404 for a job that left its set" do
      menu("dead")

      expect(status).to eq(404)
    end
  end

  describe "the drawer" do
    it "acts on a retry, asking before kill and delete", :aggregate_failures do
      sets["retry"].add(Time.now + 60, job)
      foot = drawer("retries")

      expect(foot.all("button").map(&:text)).to eq(["Retry now", "Kill", "Delete"])
      kill = admin_t("ui.components.jobs.set_acts.confirm.kill", job: "Social::Jobs::CrossPost")
      expect([confirm(foot, "retry"), confirm(foot, "kill")]).to eq([nil, kill])
    end

    it "acts on a scheduled job and a dead job", :aggregate_failures do
      sets["schedule"].add(Time.now + 600, job)
      sets["dead"].add(Time.now - 60, job("jid" => "abc"))

      expect(drawer("scheduled").all("button").map(&:text)).to eq(["Run now", "Delete"])
      get "/admin/settings/jobs?open=dead&jid=abc"
      expect(page.find("dialog#jobs-job .dialog-foot").all("button").map(&:text)).to eq(["Retry now", "Discard"])
    end

    it "brings each action back to the open drawer" do
      sets["retry"].add(Time.now + 60, job)

      expect(drawer("retries").all("input[name=return_to]", visible: :all).map(&:value).uniq)
        .to eq(["/admin/settings/jobs?open=retries&jid=#{jid}"])
    end
  end
end
