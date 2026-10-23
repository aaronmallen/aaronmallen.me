# frozen_string_literal: true

security = Security::Slice
return if security["repos.device_queries"].newest_first.any? || security["repos.sighting_queries"].newest_first.any?

hash_visitor = Analytics::Slice["operations.hash_visitor"]
places = {
  home: { city: "Chicago", country: "US", country_name: "United States" },
  away: { city: "Amsterdam", country: "NL", country_name: "Netherlands" },
}
agents = {
  mac: "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 Version/17.5 Safari/605.1.15",
  phone: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5) AppleWebKit/605.1.15 Version/17.5 Mobile/15E148 Safari/604.1",
  linux: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36",
}
read_device = security["operations.read_device"]
sign_ins = security["repos.sign_in_mutations"]

sign_in = lambda do |outcome, address, agent, place, days_ago, device_id: nil|
  user_agent = agents.fetch(agent)

  sign_ins.create(
    outcome:, provider: "github", address:, user_agent:, **read_device.call(user_agent), **places.fetch(place),
    visitor_hash: hash_visitor.throttle_hashes(address).first, device_id:,
    created_at: Seeds.ago(days_ago, hour: 9),
  ).id
end

device_mutations = security["repos.device_mutations"]
known_device_mutations = security["repos.known_device_mutations"]
devices = { mac: ["192.0.2.40", :home, 6], phone: ["192.0.2.41", :home, 2], linux: ["198.51.100.40", :away, 20] }
devices.each do |agent, (address, place, days_ago)|
  found = read_device.call(agents.fetch(agent))
  known_device_mutations.know(**found, **places.fetch(place), at: Seeds.ago(days_ago, hour: 9))
  device_id = device_mutations.sign_in(nil, **found)
  sign_in.call("signed_in", address, agent, place, days_ago, device_id:)
  Seeds.unwrap(security["operations.sign_out_device"].call(device_id)) if agent == :linux
end

sign_in.call("denied", "203.0.113.7", :linux, :away, 3)
sign_in.call("wrong_account", "203.0.113.8", :phone, :away, 1)
dismissed = sign_in.call("denied", "203.0.113.9", :linux, :away, 2)
Seeds.unwrap(security["operations.dismiss_sign_in"].call(dismissed))

token = API::Slice["repos.api_token_queries"].live.first
client = API::Slice["repos.client_queries"].connected.first
sightings = security["repos.sighting_mutations"]
[
  [{ api_token_id: token.id }, "192.0.2.41", :home, "Shortcuts/2.0 CFNetwork/1494 Darwin/23.4.0 (iPhone; iOS 17_5)"],
  [{ oauth_client_id: client.id }, "192.0.2.40", :home, "claude-code/2.4.0 (Macintosh; Mac OS X 14_5)"],
  [{ oauth_client_id: client.id }, "198.51.100.40", :away, "node-fetch/1.0 (X11; Linux x86_64)"],
].each do |credential, address, place, user_agent|
  sightings.sight(
    **credential, **read_device.call(user_agent), **places.fetch(place),
    product: user_agent[%r{\A([^\s/()]+)}, 1], last_address: address, last_user_agent: user_agent,
  )
end
