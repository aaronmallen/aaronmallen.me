# frozen_string_literal: true

RSpec.describe Mail::Jobs::BackfillGmail do
  let(:address) { "aaron@example.com" }

  def asked_for(query) = a_request(:get, %r{/threads\?}).with(query: hash_including(query))

  def backfill(page_token = nil) = described_class.new.perform(address, page_token)

  def queued = described_class.jobs.map { it["args"] }

  def rate_limited(status: 403)
    error = { error: { code: status, errors: [{ reason: "rateLimitExceeded", domain: "usageLimits" }] } }

    google_health_json(error).merge(status:)
  end

  def stub_page(ids, next_page: nil)
    stub_request(:get, %r{/gmail/v1/users/me/threads\?})
      .to_return(google_health_json({ threads: ids.map { { id: it } }, nextPageToken: next_page }.compact))
  end

  def threads = Mail::Slice["relations.mail_threads"].where(Sequel.~(gmail_id: nil)).pluck(:gmail_id)

  before { connect_google(account_id: address, scopes: Spec::GoogleAccounts::GMAIL_SCOPES) }

  def waits = described_class.jobs.map { (it["at"] - Time.now.to_f).round }

  it "stores every thread on the page, and asks Gmail for spam but not trash", :aggregate_failures do
    stub_gmail(threads: { "t1" => [gmail_message("m1")], "t2" => [gmail_message("m2", labels: %w[SPAM])] })
    stub_page(%w[t1 t2])
    backfill

    expect(threads).to contain_exactly("t1", "t2")
    expect(asked_for("includeSpamTrash" => "true", "q" => "-in:trash")).to have_been_made
  end

  it "asks only for threads inside the window when a mail backfill window is set" do
    override_setting(:mail, :backfill_days, to: 90)
    stub_page([])
    backfill

    expect(asked_for("q" => "-in:trash newer_than:90d")).to have_been_made
  end

  it "queues the next page half a minute out, so a full mailbox stays under Gmail's rate limit", :aggregate_failures do
    stub_page([], next_page: "page-2")
    backfill

    expect(queued).to eq([[address, "page-2"]])
    expect(waits).to eq([30])
  end

  describe "a page Gmail rate limits partway through" do
    before do
      stub_gmail(threads: { "t1" => [gmail_message("m1")] })
      stub_page(%w[t1 t2], next_page: "page-3")
      stub_request(:get, %r{/threads/t2\?}).to_return(rate_limited)
    end

    it "queues the same page again in two minutes rather than failing", :aggregate_failures do
      expect { backfill("page-2") }.not_to raise_error
      expect([queued, waits]).to eq([[[address, "page-2"]], [120]])
    end

    it("keeps the threads it stored before the limit") { expect { backfill }.to change { threads }.to(%w[t1]) }
  end

  it "treats a 429 from Gmail as a rate limit too" do
    stub_request(:get, %r{/threads\?}).to_return(rate_limited(status: 429))
    backfill

    expect(queued).to eq([[address, nil]])
  end

  it "asks Gmail for the page it was queued with" do
    stub_page([])
    backfill("page-2")

    expect(a_request(:get, %r{/threads\?}).with(query: hash_including("pageToken" => "page-2"))).to have_been_made
  end

  it "stops after the last page" do
    stub_page([])
    backfill

    expect(queued).to be_empty
  end

  describe "a backfill whose page fails past its retries" do
    def an_hour_passes
      held = Mail::Slice["relations.mail_accounts"].where(address:).dataset.exclude(backfill_held_at: nil)
      held.update(backfill_held_at: Time.now - 3601)
    end

    def run_out_of_retries(page_token)
      4.times { backfill(page_token) rescue Mail::Error }
    end

    def sync
      described_class.jobs.clear
      Mail::Jobs::SyncGmail.new.perform
    end

    before do
      stub_gmail
      sync
      stub_page([], next_page: "page-2")
      backfill
      stub_request(:get, %r{/threads\?.*pageToken=page-2}).to_return(status: 503)
      run_out_of_retries("page-2")
    end

    it "goes on from that page once the scheduled sync finds it stalled" do
      an_hour_passes
      sync

      expect(queued).to eq([[address, "page-2"]])
    end

    it "is left alone while it might still be retrying" do
      sync

      expect(queued).to be_empty
    end

    it "is queued again only once" do
      an_hour_passes
      sync
      sync

      expect(queued).to be_empty
    end

    describe "for an account that lost its Google connection" do
      def connections = Services::Slice["relations.service_connections"].where(account_id: address).dataset

      def revoke(at = Time.now) = connections.update(revoked_at: at)

      it "is not queued again while the connection is revoked" do
        revoke
        an_hour_passes
        sync

        expect(queued).to be_empty
      end

      it "is not queued again once the connection is gone" do
        connections.delete
        an_hour_passes
        sync

        expect(queued).to be_empty
      end

      it "goes on from its saved page once the account reconnects" do
        revoke
        an_hour_passes
        sync.then { revoke(nil) }
        sync

        expect(queued).to eq([[address, "page-2"]])
      end
    end

    it "is never queued again once it reads its last page" do
      stub_page([])
      backfill("page-2")
      an_hour_passes
      sync

      expect(queued).to be_empty
    end
  end

  it "raises when Google fails, so Sidekiq tries the page again" do
    stub_request(:get, %r{/threads\?}).to_return(status: 503)

    expect { backfill }.to raise_error(Mail::Error, "Google answered 503")
  end
end
