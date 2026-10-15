# frozen_string_literal: true

RSpec.describe Mail::Jobs::RecleanMailHtml do
  let(:address) { "aaron@example.com" }

  def html(id, html) = gmail_message("m#{id}", parts: [gmail_part("text/html", html)])

  def html_bodies = messages.order(:gmail_id).pluck(:html_body)

  def messages = Mail::Slice["relations.mail_messages"]

  def queued = described_class.jobs.map { it["args"] }

  def rate_limited
    error = { error: { code: 429, errors: [{ reason: "rateLimitExceeded", domain: "usageLimits" }] } }

    google_health_json(error).merge(status: 429)
  end

  def reclean(*) = described_class.new.perform(*)

  def store(id)
    repo = Mail::Slice["repos.gmail_mutations"]
    thread = JSON.parse({ id:, messages: [html(id, "<p>#{id}</p>")] }.to_json)
    repo.store_thread(repo.account(address).id, Mail::GmailThread.new(thread))
  end

  def waits = described_class.jobs.map { (it["at"] - Time.now.to_f).round }

  before do
    connect_google(account_id: address, scopes: Spec::GoogleAccounts::GMAIL_SCOPES)
    store("t1")
    store("t2")
    messages.dataset.update(html_body: %(<p id="nav">Old</p>))
    allow(Sidekiq.logger).to receive(:info)
  end

  it "rewrites each stored message's HTML under the current config" do
    stub_gmail(threads: { "t1" => [html("t1", %(<p id="x">One<script>x()</script></p>))],
                          "t2" => [html("t2", "<p>Two</p>")] })
    reclean

    expect(html_bodies).to eq([%(<p id="x">One</p>), "<p>Two</p>"])
  end

  it "leaves a thread Gmail no longer has as it is, and counts it", :aggregate_failures do
    stub_gmail(threads: { "t2" => [html("t2", "<p>Two</p>")] })
    stub_request(:get, %r{/threads/t1\?}).to_return(status: 404)
    reclean.then { reclean(*queued.first) }

    expect(html_bodies).to eq([%(<p id="nav">Old</p>), "<p>Two</p>"])
    expect(Sidekiq.logger).to have_received(:info).with(format(described_class::DONE, 1))
  end

  it "queues the threads after the last one it cleaned, half a minute out", :aggregate_failures do
    stub_gmail(threads: { "t1" => [gmail_message("mt1")], "t2" => [gmail_message("mt2")] })
    reclean

    expect(queued).to eq([[Mail::Slice["relations.mail_threads"].where(gmail_id: "t2").pluck(:id).first, 0]])
    expect(waits).to eq([30])
  end

  it "queues the same threads again in two minutes when Gmail rate limits it" do
    stub_request(:get, %r{/threads/}).to_return(rate_limited)
    reclean(0, 2)

    expect([queued, waits]).to eq([[[0, 2]], [120]])
  end

  it "raises when Google fails, so Sidekiq tries again" do
    stub_request(:get, %r{/threads/}).to_return(status: 503)

    expect { reclean }.to raise_error(Mail::Error, "Google answered 503")
  end
end
