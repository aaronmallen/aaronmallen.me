# frozen_string_literal: true

module MCPAuthorize
  AUTHORIZE_PATH = "/oauth/authorize"

  def approve_authorization(path) = decide_authorization(path, "approve")

  def authorization_fields
    form = Capybara.string(last_response.body).first("form[action='#{AUTHORIZE_PATH}']", visible: :all)
    form.all("input[type='hidden']", visible: :all).to_h { |input| [input[:name], input.value] }
  end

  def cancel_authorization(path) = decide_authorization(path, "cancel")

  def decide_authorization(path, decision)
    get path
    post AUTHORIZE_PATH, authorization_fields.merge("decision" => decision)
  end
end

RSpec.configure do |config|
  config.include MCPAuthorize, type: :request
end
