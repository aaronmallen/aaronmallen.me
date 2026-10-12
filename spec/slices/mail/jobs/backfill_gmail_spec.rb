# frozen_string_literal: true

RSpec.describe Mail::Jobs::BackfillGmail do
  let(:address) { "aaron@example.com" }

  def backfill(page_token = nil) = described_class.new.perform(address, page_token)

  def queued = described_class.jobs.map { it["args"] }

  def stub_page(ids, next_page: nil)
    stub_request(:get, %r{/gmail/v1/users/me/threads\?})
      .to_return(google_health_json({ threads: ids.map { { id: it } }, nextPageToken: next_page }.compact))
  end

  def threads = Mail::Slice["relations.mail_threads"].where(Sequel.~(gmail_id: nil)).pluck(:gmail_id)

  before { connect_google(account_id: address, scopes: Spec::GoogleAccounts::GMAIL_SCOPES) }

  it "stores every thread on the page, spam and trash with them", :aggregate_failures do
    stub_gmail(threads: { "t1" => [gmail_message("m1")], "t2" => [gmail_message("m2", labels: %w[TRASH])] })
    stub_page(%w[t1 t2])
    backfill

    expect(threads).to contain_exactly("t1", "t2")
    expect(a_request(:get, %r{/threads\?}).with(query: hash_including("includeSpamTrash" => "true"))).to have_been_made
  end

  it "queues the next page" do
    stub_page([], next_page: "page-2")
    backfill

    expect(queued).to eq([[address, "page-2"]])
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

  it "raises when Google fails, so Sidekiq tries the page again" do
    stub_request(:get, %r{/threads\?}).to_return(status: 503)

    expect { backfill }.to raise_error(Mail::Error, "Google answered 503")
  end
end
