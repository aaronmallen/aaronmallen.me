# frozen_string_literal: true

RSpec.describe "Admin private tag fields", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def choices = get("/admin/tags/private/choices", {}, { "HTTP_ACCEPT" => "application/json" })

  def edit_template = last_response.body[%r{<template.*?</template>}m].to_s

  def names(selector)
    page.all(selector, visible: :all).map { JSON.parse(picker(it)["data-tag-field"]).map { |tag| tag["name"] } }
  end

  def picker(field) = field.find(:xpath, "following-sibling::*[1]", visible: :all)

  def sources(selector) = page.all(selector, visible: :all).map { picker(it)["data-tag-field-src"] }

  it "answers 401 to the tag list when signed out" do
    choices

    expect(last_response.status).to eq(401)
  end

  describe "signed in" do
    before do
      sign_in_to_admin
      create(:tag, name: "ruby")
      create(:tag, :private, name: "chores", color: "mk-green")
      create(:task, tags: %w[health])
      create(:message).tap { Mail::Slice["repos.message_tag_mutations"].add(it.id, "billing") }
    end

    it "lists the private tags in their colors, leaving out public and mail-only tags", :aggregate_failures do
      choices

      expect(last_response.media_type).to eq("application/json")
      expect(JSON.parse(last_response.body)).to match(
        "tags" => [{ "name" => "chores", "color" => "green" }, { "name" => "health", "color" => String }],
      )
    end

    it "forbids caching the tag list" do
      choices

      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end

    it "points the task form at the private tags", :aggregate_failures do
      get "/admin/tasks/new"
      field = page.first("main input[name='task[tags]']", visible: :all)

      expect(picker(field)["data-tag-field-src"]).to eq("/admin/tags/private/choices")
      expect(field.find(:xpath, "..")).to have_css("label[for='#{field[:id]}']", text: "Tags", visible: :all)
    end

    it "points the task drawer's edit form at the private tags" do
      get "/admin/tasks/#{create(:task).id}/edit"

      expect(sources("input[name='task[tags]']").uniq).to eq(["/admin/tags/private/choices"])
    end

    it "points the journal box, the write dialog and the edit form template at the private tags" do
      create(:journal_entry, body: "one")
      get "/admin/journal"

      expect([sources("input[name='entry[tags]']"), edit_template]).to match(
        [["/admin/tags/private/choices"] * 2, include('data-tag-field-src="/admin/tags/private/choices"')],
      )
    end

    it "points the decision editors at the private tags" do
      get "/admin/decisions/new"
      fresh = sources("input[name='decision[tags]']")
      get "/admin/decisions/#{create(:decision).id}/edit"

      expect(fresh + sources("input[name='decision[tags]']")).to eq(["/admin/tags/private/choices"] * 2)
    end

    it "suggests private tags on the task rule forms" do
      Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "chores" }).value!
      get "/admin/settings/tagging"

      expect(names("input[name='rule[tags]']")).to eq([%w[chores health]] * 2)
    end

    it "keeps the comma field for a save without scripts" do
      get "/admin/tasks/#{create(:task, tags: %w[chores health]).id}/edit"

      expect(page).to have_field("task[tags]", with: "chores, health")
    end
  end
end
