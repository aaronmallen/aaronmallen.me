# frozen_string_literal: true

RSpec.describe "Admin file moves", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:first) { upload_share("a", "one.txt").value! }
  let(:second) { upload_share("b", "two.txt").value! }
  let(:group) do
    Shares::Slice["operations.upload_share_group"].call([share_upload("c", "three.txt", "text/plain")]).value!
  end

  def bulk(act, ids, **params) = post("/admin/files/bulk", { act:, "ids" => ids.map(&:to_s), **params }, csrf)

  def codes = Shares::Slice["relations.short_codes"].pluck(:code)

  def csrf = { "HTTP_X_CSRF_TOKEN" => admin_csrf_token }

  def groups = Shares::Slice["relations.share_groups"].to_a

  def row(id) = Shares::Slice["relations.share_group_files"].by_pk(id).one

  before do
    sign_in_to_admin
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
  end

  describe "the list" do
    before do
      first
      group
      get "/admin/files"
    end

    it "ticks a single share into the bulk form" do
      expect(page).to have_css(".file-card input[name='ids[]'][value='#{first.id}'][form='files-bulk']")
    end

    it "offers to make a group or add to one by name", :aggregate_failures do
      form = page.find("form#files-bulk")

      expect(form).to have_button("Make a group")
      expect(form).to have_select("group_id", with_options: [group.code])
    end

    it "offers to pull each group file out" do
      expect(page).to have_css(
        "form#share-group-#{group.id}-ungroup-#{group.share_group_files.first.id}" \
        "[action='/admin/files/groups/#{group.id}/files/#{group.share_group_files.first.id}/ungroup']",
        visible: :all,
      )
    end
  end

  describe "making a group" do
    it "gathers the ticked shares under one new group and frees their old codes", :aggregate_failures do
      old = [first.code, second.code]
      bulk("group", [first.id, second.id])

      expect([row(first.id)[:share_group_id], row(second.id)[:share_group_id]]).to eq([groups.last[:id]] * 2)
      expect(codes & old).to be_empty
    end

    it "says it grouped them" do
      bulk("group", [first.id, second.id])
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "Grouped 2 files under")
    end

    it "keeps each file's id and downloads", :aggregate_failures do
      Shares::Slice["relations.share_group_files"].by_pk(first.id).update(download_count: 3)
      bulk("group", [first.id, second.id])

      expect(row(first.id)).to include(download_count: 3, short_code_id: nil)
    end

    it "refuses one file", :aggregate_failures do
      bulk("group", [first.id])
      follow_redirect!

      expect(groups).to be_empty
      expect(page).to have_css("[data-toast]", text: "tick two or more files")
    end

    it "moves nothing when a ticked share is gone", :aggregate_failures do
      bulk("group", [first.id, 999_999])
      follow_redirect!

      expect([groups, row(first.id)[:short_code_id]]).to eq([[], first.short_code_id])
      expect(page).to have_css("[data-toast]", text: "a file or the group is gone")
    end

    it "does not take a group's file as a single share" do
      bulk("group", [first.id, group.share_group_files.first.id])

      expect(groups.size).to eq(1)
    end
  end

  describe "adding to a group" do
    it "moves the ticked shares into the group and frees their codes", :aggregate_failures do
      old = first.code
      bulk("add", [first.id, second.id], group_id: group.id.to_s)

      expect([row(first.id)[:share_group_id], row(second.id)[:share_group_id]]).to eq([group.id] * 2)
      expect(codes).not_to include(old)
    end

    it "says it moved them" do
      bulk("add", [first.id, second.id], group_id: group.id.to_s)
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "Moved 2 files into #{group.code}")
    end

    it "asks for a group when none is picked" do
      bulk("add", [first.id], group_id: "")
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "pick a group first")
    end

    it "asks for a file when none is ticked" do
      bulk("add", [], group_id: group.id.to_s)
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "tick a file first")
    end
  end

  describe "pulling a file out" do
    let(:file) { group.share_group_files.first }

    def ungroup = post("/admin/files/groups/#{group.id}/files/#{file.id}/ungroup", {}, csrf)

    it "gives it its own new code and keeps its downloads", :aggregate_failures do
      Shares::Slice["relations.share_group_files"].by_pk(file.id).update(download_count: 2)
      ungroup

      expect(Shares::Slice["repos.share_queries"].find(file.id).code).not_to eq(group.code)
      expect(row(file.id)).to include(share_group_id: nil, download_count: 2)
    end

    it "says it moved it" do
      ungroup
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "Moved out of the group under a new link")
    end

    it "answers 404 for a file outside the group" do
      post("/admin/files/groups/#{group.id}/files/#{first.id}/ungroup", {}, csrf)

      expect(last_response).to be_not_found
    end
  end
end
