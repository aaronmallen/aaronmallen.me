# frozen_string_literal: true

RSpec.describe Mail::Repos::GmailMutations, "#store_labels" do
  let(:account) { repo.account("aaron@example.com") }
  let(:repo) { Mail::Slice["repos.gmail_mutations"] }

  def labels = Mail::Slice["relations.mail_labels"].dataset.unordered.order(:gmail_id).select_map(%i[gmail_id name])

  def store(names) = repo.store_labels(account.id, names.map { |gmail_id, name| { gmail_id:, name: } })

  before { store("Label_1" => "Receipts", "Label_2" => "Travel") }

  it "stores both names when two labels swap them" do
    store("Label_1" => "Travel", "Label_2" => "Receipts")

    expect(labels).to eq([%w[Label_1 Travel], %w[Label_2 Receipts]])
  end

  it "stores both names when a label takes the name another gave up" do
    store("Label_1" => "Travel", "Label_2" => "Trips")

    expect(labels).to eq([%w[Label_1 Travel], %w[Label_2 Trips]])
  end

  it "still refuses two labels with one name" do
    expect { store("Label_1" => "Travel", "Label_2" => "Travel") }.to raise_error(Sequel::UniqueConstraintViolation)
  end
end
