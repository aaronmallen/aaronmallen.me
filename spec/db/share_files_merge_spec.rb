# frozen_string_literal: true

RSpec.describe "Single shares and group files in one table", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }

  def file(**) = { key: SecureRandom.hex(16), filename: "a.txt", content_type: "text/plain", byte_size: 2, ** }

  def short_code(code) = db[:short_codes].insert(code:)

  it "refuses a file with both a code and a group" do
    group = db[:share_groups].insert(short_code_id: short_code("the-deck"))

    expect { db[:share_group_files].insert(file(short_code_id: short_code("cat-file"), share_group_id: group)) }
      .to raise_error(Sequel::CheckConstraintViolation)
  end

  it "refuses a file with neither a code nor a group" do
    expect { db[:share_group_files].insert(file) }.to raise_error(Sequel::CheckConstraintViolation)
  end

  it "keeps a group's files out of the single shares" do
    group = db[:share_groups].insert(short_code_id: short_code("the-deck"))
    db[:share_group_files].insert(file(share_group_id: group))

    expect(Shares::Slice["repos.share_queries"].totals).to eq(count: 0, bytes: 0)
  end
end
