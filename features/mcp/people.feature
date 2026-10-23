Feature: People through MCP
  The MCP people tools do what the people endpoints do. Without the contacts
  permission they see and change only the open fields.

  Background:
    Given I am signed in to the admin

  Scenario: The MCP people tools list, read, add, edit and delete people
    Given a contact "Ada" with:
      """
      {"company": "Analytical Engines"}
      """
    And a contact "Grace"
    When an MCP client connects with the scopes "read write delete contacts" and I approve it
    And I call the MCP tool "list_people" with:
      """
      {"query": "analytical"}
      """
    Then the MCP answer holds "Analytical Engines"
    And the MCP answer does not hold "Grace"
    When I call the MCP tool "read_person" for the contact "Grace" with:
      """
      {}
      """
    Then the MCP answer holds "Grace"
    When I call the MCP tool "save_person" with:
      """
      {"name": "Katherine", "key": "kj", "mastodon_handle": "@kj@ruby.social",
        "phones": [{"value": "555-0100", "type": "mobile"}], "birthday": "--12-10"}
      """
    Then the MCP answer holds "555-0100"
    And the contact "Katherine" holds:
      """
      {"key": "kj", "phones": [{"value": "555-0100", "type": "mobile"}], "birthday": "--12-10"}
      """
    When I call the MCP tool "save_person" for the contact "Grace" with:
      """
      {"name": "Grace Hopper"}
      """
    Then the MCP answer holds "Grace Hopper"
    And the contacts are "Ada, Grace Hopper, Katherine"
    When I call the MCP tool "delete_person" for the contact "Ada" with:
      """
      {}
      """
    Then the MCP answer holds "deleted"
    And the contacts are "Grace Hopper, Katherine"
    When I call the MCP tool "read_person" with:
      """
      {"id": 999999}
      """
    Then the MCP answer holds "no person has the ID 999999"
    When I call the MCP tool "save_person" with:
      """
      {"name": "Alan", "mastodon_handle": "@alan@ruby.social"}
      """
    Then the MCP people answer is an error
    And the MCP answer holds "give a person with a handle a key"
    When I call the MCP tool "sync_people"
    Then the MCP answer holds "queued"

  Scenario: The MCP save_person tool refuses an edit Google changed first
    Given the Google account "me@example.com" is connected with "contacts"
    And a contact "Ada"
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers GET "/people/c1" with:
      """
      {"resourceName": "people/c1", "etag": "e2", "names": [{"displayName": "Ada", "metadata": {"primary": true}}]}
      """
    When an MCP client connects with the scopes "read write delete contacts" and I approve it
    And I call the MCP tool "save_person" for the contact "Ada" with:
      """
      {"name": "Ada King"}
      """
    Then the MCP answer holds "Google changed this contact first, so nothing changed; read it again and redo the edit"

  Scenario: The MCP people tools without the contacts permission see and save only the open fields
    Given a contact "Ada" with:
      """
      {"company": "Analytical Engines"}
      """
    When an MCP client connects with the scopes "read write delete" and I approve it
    And I call the MCP tool "list_people"
    Then the MCP answer holds "Ada"
    And the MCP answer does not hold "Analytical Engines"
    When I call the MCP tool "read_person" for the contact "Ada" with:
      """
      {}
      """
    Then the MCP answer does not hold "Analytical Engines"
    When I call the MCP tool "save_person" with:
      """
      {"name": "Grace", "company": "Navy"}
      """
    Then the MCP people answer is an error
    And the MCP answer holds "this endpoint needs a token with the contacts scope"
    And the contacts are "Ada"
    When I call the MCP tool "save_person" with:
      """
      {"name": "Grace", "key": "grace"}
      """
    Then the MCP answer holds "grace"
    And the contacts are "Ada, Grace"
    And the MCP tools for people leave out "delete_person, sync_people"

  Scenario: The MCP search_accounts tool searches as the endpoint does and marks each name untrusted
    Given the admin can search people on "Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with:
      """
      {"actors": [{"displayName": "Ada", "handle": "ada.bsky.social"}]}
      """
    When an MCP client connects with the scopes "read" and I approve it
    And I call the MCP tool "search_accounts" with:
      """
      {"network": "bluesky", "query": "ada"}
      """
    Then the MCP answer holds "ada.bsky.social"
    And the MCP answer holds "untrusted"
    When I call the MCP tool "search_accounts" with:
      """
      {"network": "mastodon", "query": "grace"}
      """
    Then the MCP answer holds "Mastodon has no credentials, so it cannot be searched"

  Scenario: The MCP search_accounts tool refuses a network that rate limits
    Given the admin can search people on "Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with status 429
    When an MCP client connects with the scopes "read" and I approve it
    And I call the MCP tool "search_accounts" with:
      """
      {"network": "bluesky", "query": "ada"}
      """
    Then the MCP people answer is an error
