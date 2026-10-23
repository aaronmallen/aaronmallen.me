# frozen_string_literal: true

module GitHubRest
  API = "http://stub.localhost/github/api"

  def stub_github_repo(repo, stars:, release:)
    stub_request(:get, "#{API}/repos/#{repo}").to_return(github_json({ full_name: repo, stargazers_count: stars }))
    stub_request(:get, "#{API}/repos/#{repo}/releases/latest").to_return(github_json({ tag_name: release }))
  end
end

RSpec.configure do |config|
  config.include GitHubRest
end
