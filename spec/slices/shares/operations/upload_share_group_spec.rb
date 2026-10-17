# frozen_string_literal: true

RSpec.describe Shares::Operations::UploadShareGroup do
  let(:stored) { {} }

  def fail_second_put
    stub_request(:put, %r{\A#{share_store_url}/}).to_return do |request|
      next { status: 500 } unless stored.empty?

      stored[File.basename(request.uri.path)] = request.body
      { status: 200 }
    end
  end

  def files = Shares::Slice["relations.share_group_files"].to_a

  def groups = Shares::Slice["relations.share_groups"].to_a

  def keep_deletes
    stub_request(:delete, %r{\A#{share_store_url}/}).to_return do |request|
      stored.delete(File.basename(request.uri.path))
      { status: 204 }
    end
  end

  def keep_puts
    stub_request(:put, %r{\A#{share_store_url}/}).to_return do |request|
      stored[File.basename(request.uri.path)] = { body: request.body.b, content_type: request.headers["Content-Type"] }
      { status: 200 }
    end
  end

  def upload(*uploads) = Shares::Slice["operations.upload_share_group"].call(uploads)

  describe "with a store" do
    before do
      connect_share_store
      keep_puts
    end

    describe "two files" do
      let!(:group) do
        upload(share_upload("a", "a.txt", "text/plain"), share_upload("%PDF", "b.pdf", "application/pdf")).value!
      end

      it "makes one group under one three character code", :aggregate_failures do
        expect(group.code).to match(/\A[abcdefghjkmnpqrstuvwxyz23456789]{3}\z/)
        expect(group).to have_attributes(view_count: 0, zip_download_count: 0)
        expect(Shares::Slice["relations.shares"].count).to eq(0)
      end

      it "keeps each file's name, type and size" do
        expect(group.share_group_files.map { [it.filename, it.content_type, it.byte_size] })
          .to contain_exactly(["a.txt", "text/plain", 1], ["b.pdf", "application/pdf", 4])
      end

      it "stores each file byte for byte under its own key", :aggregate_failures do
        expect(stored.keys).to match_array(group.share_group_files.map(&:key))
        expect(stored.values).to contain_exactly(
          { body: "a", content_type: "text/plain" }, { body: "%PDF", content_type: "application/pdf" },
        )
      end
    end

    it "calls a file sent with no type an octet stream" do
      group = upload(share_upload("data", "blob", "")).value!

      expect(group.share_group_files.map(&:content_type)).to eq(["application/octet-stream"])
    end

    it "tries a new code when the first is taken" do
      Shares::Slice["relations.short_codes"].insert(code: "aaa")
      allow(Shares::Helpers::Code).to receive(:pick).and_return("aaa", "bbb")

      expect(upload(share_upload("a", "a.txt", "text/plain")).value!.code).to eq("bbb")
    end

    it "refuses no files" do
      expect(upload.failure).to eq([:blank])
    end

    it "refuses the group when one file has no name and stores nothing", :aggregate_failures do
      result = upload(share_upload("a", "a.txt", "text/plain"), share_upload("b", " ", "text/plain"))

      expect(result.failure).to eq([:invalid, { filename: ["blank"] }])
      expect(groups).to be_empty
      expect(stored).to be_empty
    end

    it "saves no rows and keeps no files when the store fails on the second", :aggregate_failures do
      fail_second_put
      keep_deletes

      result = upload(share_upload("a", "a.txt", "text/plain"), share_upload("b", "b.txt", "text/plain"))

      expect(result.failure).to eq([:unavailable])
      expect([groups, files, Shares::Slice["relations.short_codes"].to_a, stored]).to all(be_empty)
    end
  end

  it "refuses an upload with no store" do
    expect(upload(share_upload("a", "a.txt", "text/plain")).failure).to eq([:unavailable])
  end

  describe "in Postgres" do
    let(:code_id) { Shares::Slice["relations.short_codes"].insert(code: "group") }

    it "lets one code hold one group" do
      Shares::Slice["relations.share_groups"].insert(short_code_id: code_id)

      expect { Shares::Slice["relations.share_groups"].insert(short_code_id: code_id) }
        .to raise_error(Sequel::UniqueConstraintViolation)
    end

    it "drops the group and its files with the code" do
      group_id = Shares::Slice["relations.share_groups"].insert(short_code_id: code_id)
      Shares::Slice["relations.share_group_files"]
        .insert(share_group_id: group_id, key: "0" * 32, filename: "a.txt", content_type: "text/plain", byte_size: 1)
      Shares::Slice["relations.short_codes"].by_pk(code_id).delete

      expect([groups, files]).to all(be_empty)
    end
  end
end
