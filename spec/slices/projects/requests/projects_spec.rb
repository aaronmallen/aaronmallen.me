# frozen_string_literal: true

RSpec.describe "Projects", type: :request do
  let(:repo) { Projects::Slice["repos.project_queries"] }

  before { sign_in_to_admin }

  describe "moving" do
    it "has no route" do
      project = create(:project)
      post "/admin/projects/#{project.id}/move/up", _csrf_token: admin_csrf_token

      expect(last_response.status).to eq(404)
    end
  end

  describe "archiving" do
    it "keeps the repo, the stars and the visibility" do
      project = create(:project, :private, repo: "aaronmallen/kept", stars: 12)
      post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token

      expect(repo.by_id(project.id)).to have_attributes(repo: "aaronmallen/kept", stars: 12, visibility: "private")
    end
  end

  describe "restoring" do
    it "clears the archive date" do
      project = create(:project)
      post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token
      post "/admin/projects/#{project.id}/restore", _csrf_token: admin_csrf_token

      expect(repo.by_id(project.id)).to have_attributes(archived_on: nil, archived?: false)
    end
  end
end
