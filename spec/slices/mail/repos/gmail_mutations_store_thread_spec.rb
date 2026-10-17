# frozen_string_literal: true

RSpec.describe Mail::Repos::GmailMutations, "#store_thread" do
  let(:account) { repo.account("aaron@example.com") }
  let(:repo) { Mail::Slice["repos.gmail_mutations"] }

  def attachment(part_id, size: 4)
    { **gmail_part("application/pdf", "%PDF"), partId: part_id, filename: "#{part_id}.pdf", body: { size: } }
  end

  def attachment_rows
    table(:mail_attachments).select(Sequel[:ctid].cast(:text).as(:ctid), :mail_message_id, :size).to_a
  end

  def message(id, labels: %w[INBOX UNREAD], files: [attachment("2")], **)
    gmail_message(id, labels:, at: Time.at(1_700_000_000), parts: [gmail_part("text/plain", "Hello"), *files], **)
  end

  def snapshot
    {
      threads: table(:mail_threads).select_map(%i[status starred updated_at]),
      messages: table(:mail_messages).order(:gmail_id).select_map(%i[gmail_id subject updated_at]),
      attachments: attachment_rows, labels: table(:mail_thread_labels).count,
    }
  end

  def store(*messages, at: Time.now)
    thread = Mail::Slice["operations.parse_gmail_thread"].call(JSON.parse({ id: "t1", messages: }.to_json))
    repo.store_thread(account.id, thread, now: at)
  end

  def table(name) = Mail::Slice["relations.#{name}"].dataset.unordered

  before do
    repo.store_labels(account.id, [{ gmail_id: "Label_1", name: "Receipts" }])
    store(message("m1", labels: %w[INBOX UNREAD Label_1]), message("m2"), at: Time.now - 60)
  end

  it "leaves every row alone when the thread has not changed" do
    expect { store(message("m1", labels: %w[INBOX UNREAD Label_1]), message("m2")) }.not_to(change { snapshot })
  end

  it "updates the thread when a flag changes", :aggregate_failures do
    store(message("m1", labels: %w[INBOX STARRED Label_1]), message("m2", labels: %w[INBOX]))

    expect(table(:mail_threads).first).to include(status: "read", starred: true)
    expect(table(:mail_threads).first[:updated_at]).to be > Time.now - 30
  end

  it "replaces a label that changed" do
    store(message("m1"), message("m2"))

    expect(table(:mail_thread_labels).count).to eq(0)
  end

  it "updates only the message that changed", :aggregate_failures do
    before = table(:mail_messages).where(gmail_id: "m2").first

    store(message("m1", labels: %w[INBOX UNREAD Label_1], Subject: "Looms"), message("m2"))

    expect(table(:mail_messages).where(gmail_id: "m1").first).to include(subject: "Looms")
    expect(table(:mail_messages).where(gmail_id: "m2").first).to eq(before)
  end

  it "replaces only the attachments that changed", :aggregate_failures do
    kept = attachment_rows.find { it[:mail_message_id] == table(:mail_messages).where(gmail_id: "m2").get(:id) }
    store(message("m1", labels: %w[INBOX UNREAD Label_1], files: [attachment("2", size: 9)]), message("m2"))

    expect(attachment_rows.map { it[:size] }).to contain_exactly(9, 4)
    expect(attachment_rows).to include(kept)
  end

  it "adds a message that arrived" do
    store(message("m1", labels: %w[INBOX UNREAD Label_1]), message("m2"), message("m3"))

    expect(table(:mail_messages).select_map(:gmail_id)).to contain_exactly("m1", "m2", "m3")
  end
end
