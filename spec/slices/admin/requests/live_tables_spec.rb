# frozen_string_literal: true

RSpec.describe "Admin live tables", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:screens) do
    %w[
      /admin /admin/activity /admin/agents/sessions /admin/analytics /admin/calendar /admin/decisions
      /admin/decisions/new /admin/files /admin/health /admin/inbox /admin/journal /admin/links /admin/mail
      /admin/mail/settings /admin/people/new /admin/performance /admin/performance/requests /admin/posts
      /admin/posts/new /admin/projects /admin/projects/new /admin/review /admin/search /admin/settings/jobs
      /admin/settings/security /admin/settings/services /admin/settings/socials /admin/settings/tagging /admin/social
      /admin/tasks /admin/tasks/new /admin/time /admin/webmentions
    ]
  end
  let(:records) do
    decision = create(:decision)
    project = create(:project)
    post = create(:post)
    task = create(:task)

    [
      "/admin/decisions/#{decision.id}", "/admin/decisions/#{decision.id}/edit", "/admin/projects/#{project.id}",
      "/admin/projects/#{project.id}/edit", "/admin/posts/#{post.id}/edit", "/admin/posts/#{post.id}/analytics",
      "/admin/tasks/#{task.id}", "/admin/tasks/#{task.id}/edit", "/admin/commits/#{create(:commit).id}",
      "/admin/pull-requests/#{create(:pull_request).id}", "/admin/tags/#{create(:tag).name}",
      "/admin/people/#{create(:person).id}/edit", "/admin/files/#{upload_share.value!.id}/edit",
      "/admin/files/groups/#{file_group.id}/edit", "/admin/links/#{short_link.id}/edit",
      "/admin/agents/sessions?session=#{agent_session}",
    ]
  end

  def agent_session
    params = { title: "Spike", agent: "claude-code", model: "claude-opus-5-5", task_ids: [] }
    Agents::Slice["operations.start_session"].call(params).value!.first
  end

  def file_group
    Shares::Slice["operations.upload_share_group"].call([share_upload("a", "a.txt", "text/plain")]).value!
  end

  def short_link = Shares::Slice["operations.create_short_link"].call({ destination: "https://example.com" }).value!

  def tables = page.find("main")["data-live-tables"]&.split

  before do
    sign_in_to_admin
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
  end

  it "lists the tables on every live page", :aggregate_failures do
    (screens + records).each do |path|
      get path

      expect(last_response.status).to eq(200), path
      expect(tables).to include("tasks", "mail_threads"), path
    end
  end

  it "lists them on a page nothing lives at" do
    get "/admin/nowhere"

    expect(tables).to include("tasks")
  end

  it "lists the tables a page draws beside the ones the top bar reads" do
    get "/admin/calendar"

    expect(tables).to include("calendar_events", "task_tags", "tasks")
  end

  it "lists the tables of both the tags and the task rules on the tagging tab" do
    get "/admin/settings/tagging"

    expect(tables).to include("post_tags", "task_tags", "task_rules", "task_rule_projects", "projects")
  end

  it "lists the tables of both the people and the webmention settings on the socials tab" do
    get "/admin/settings/socials"

    expect(tables).to include("service_connections", "posts", "trusted_authors", "webmention_settings")
  end

  it "lists the tables of both the services and the MCP clients on the connected services tab" do
    get "/admin/settings/services"

    expect(tables).to include("service_connections", "sync_states", "webmention_settings", "oauth_clients",
                              "oauth_tokens")
  end

  it "leaves out the tables a page does not draw" do
    get "/admin/calendar"

    expect(tables).not_to include("commits")
  end

  it "lists them on a form the CSRF check turns away" do
    post "/admin/tags", {}, { "HTTP_X_CSRF_TOKEN" => "wrong" }

    expect(tables).to include("tasks")
  end
end
