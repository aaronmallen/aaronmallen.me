Feature: People through the API
  The API lists, reads, adds, edits and deletes people. A token without the
  contacts scope sees and changes only the ID, name, key and handles.

  Scenario: The API lists everyone by name with every field
    Given an API token with the scopes "read write delete contacts"
    When I GET "/people" through the API
    Then the API answers 200
    And the API answer is exactly:
      """
      {"people": []}
      """
    Given a contact "Grace Hopper"
    And a contact "Ada Lovelace" with:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social", "bluesky_handle": "ada.bsky.social",
        "bluesky_did": "did:plc:ada", "company": "Analytical Engines", "emails": [{"value": "ada@example.com"}]}
      """
    When I GET "/people" through the API
    Then the API lists the people "Ada Lovelace, Grace Hopper"
    And the API person "Ada Lovelace" holds:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social", "bluesky_handle": "ada.bsky.social",
        "company": "Analytical Engines", "emails": [{"value": "ada@example.com"}], "labels": [], "starred": false}
      """

  Scenario: The API finds people by company, label and star
    Given an API token with the scopes "read write delete contacts"
    And a contact "Ada" with:
      """
      {"company": "Analytical Engines", "labels": ["Family"], "starred": true}
      """
    And a contact "Grace"
    When I GET "/people?query=analytical" through the API
    Then the API lists the people "Ada"
    When I GET "/people?label=Family" through the API
    Then the API lists the people "Ada"
    When I GET "/people?show=starred" through the API
    Then the API lists the people "Ada"

  Scenario: The API gives a token without contacts only the open fields and matches only them
    Given an API token with the scopes "read write delete"
    And a contact "Ada" with:
      """
      {"key": "countess", "mastodon_handle": "@ada@ruby.social", "company": "Analytical Engines",
        "notes": "Met at the salon", "emails": [{"value": "ada@x.io"}]}
      """
    And a contact "Grace"
    When I GET "/people" through the API
    Then each API person holds only the open fields
    And the API answer does not hold "Analytical Engines"
    When I GET "/people?query=analytical" through the API
    Then the API lists the people ""
    When I GET "/people?query=ada@x.io" through the API
    Then the API lists the people ""
    When I GET "/people?query=countess" through the API
    Then the API lists the people "Ada"
    When I GET "/people?show=mentionable" through the API
    Then the API lists the people "Ada"
    When I GET "/people?label=Family" through the API
    Then the API answers 403
    And the API answer holds "contacts"
    When I GET "/people?show=starred" through the API
    Then the API answers 403
    When I call the people API with GET "/people/:id" for "Ada"
    Then each API person holds only the open fields

  Scenario: The API reads a person
    Given an API token with the scopes "read write delete contacts"
    And a contact "Ada Lovelace" with:
      """
      {"phones": [{"value": "555-0100"}]}
      """
    When I call the people API with GET "/people/:id" for "Ada Lovelace"
    Then the API answers 200
    And the API person "Ada Lovelace" holds:
      """
      {"name": "Ada Lovelace", "phones": [{"value": "555-0100"}]}
      """

  Scenario: The API adds a person and answers them with 201
    Given an API token with the scopes "read write delete contacts"
    When I POST "/people" through the API with:
      """
      {"name": "Ada Lovelace", "key": " Ada ", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the API answers 201
    And the API person "Ada Lovelace" holds:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social", "bluesky_handle": null}
      """
    When I POST "/people" through the API with:
      """
      {"name": "Grace"}
      """
    Then the API answers 201
    And the API person "Grace" holds:
      """
      {"key": null}
      """
    And the contacts are "Ada Lovelace, Grace"

  Scenario: The API saves every private field it is given
    Given an API token with the scopes "read write delete contacts"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "name_prefix": "Countess", "given_name": "Ada", "middle_name": "Augusta", "family_name": "King",
        "name_suffix": "FRS", "phonetic_given_name": "AY-duh", "phonetic_middle_name": "aw-GUS-tuh",
        "phonetic_family_name": "KING", "nickname": "Ada", "file_as": "Lovelace, Ada", "company": "Analytical Engines",
        "job_title": "Analyst", "department": "Notes", "notes": "the first program\nfor the engine", "birthday": "--12-10",
        "emails": [{"value": " ada@example.com ", "type": "work"}], "phones": [{"value": "+44 20 7946 0000", "type": "mobile"}],
        "addresses": [{"street": "12 St James's Square", "city": "London", "country": "UK", "type": "home"}],
        "websites": [{"value": "https://example.com/ada", "type": "blog"}], "chats": [{"value": "ada", "type": "Jabber"}],
        "dates": [{"value": "1835-07-08", "type": "anniversary"}], "relations": [{"value": "William King", "type": "spouse"}],
        "custom_fields": [{"key": "Engine", "value": "Difference"}],
        "labels": [" Family ", "friends", "Family"], "starred": true}
      """
    Then the API answers 201
    And the contact "Ada" holds:
      """
      {"name_prefix": "Countess", "given_name": "Ada", "middle_name": "Augusta", "family_name": "King",
        "name_suffix": "FRS", "phonetic_given_name": "AY-duh", "phonetic_middle_name": "aw-GUS-tuh",
        "phonetic_family_name": "KING", "nickname": "Ada", "file_as": "Lovelace, Ada", "company": "Analytical Engines",
        "job_title": "Analyst", "department": "Notes", "notes": "the first program\nfor the engine", "birthday": "--12-10",
        "emails": [{"value": "ada@example.com", "type": "work"}], "phones": [{"value": "+44 20 7946 0000", "type": "mobile"}],
        "addresses": [{"street": "12 St James's Square", "city": "London", "country": "UK", "type": "home"}],
        "websites": [{"value": "https://example.com/ada", "type": "blog"}], "chats": [{"value": "ada", "type": "Jabber"}],
        "dates": [{"value": "1835-07-08", "type": "anniversary"}], "relations": [{"value": "William King", "type": "spouse"}],
        "custom_fields": [{"key": "Engine", "value": "Difference"}],
        "labels": ["Family", "friends"], "starred": true}
      """

  Scenario: The API keeps the DID a Bluesky handle resolves to
    Given an API token with the scopes "read write delete contacts"
    And Bluesky's app view answers GET "/xrpc/com.atproto.identity.resolveHandle" with:
      """
      {"did": "did:plc:ada"}
      """
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "key": "ada", "bluesky_handle": "@Ada.Bsky.Social"}
      """
    Then the contact "Ada" holds:
      """
      {"bluesky_handle": "ada.bsky.social", "bluesky_did": "did:plc:ada"}
      """

  Scenario: The API adds a person with only open fields from a token without contacts
    Given an API token with the scopes "read write delete"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "company": "Analytical Engines"}
      """
    Then the API answers 403
    And there are no contacts
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "key": "ada", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the API answers 201
    And each API person holds only the open fields

  Scenario: The API refuses a person the admin form refuses, with the reason
    Given an API token with the scopes "read write delete contacts"
    And a contact "Grace" with:
      """
      {"key": "grace"}
      """
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the API answers 422
    And the API answer is exactly:
      """
      {"error": "invalid", "message": "give a person with a handle a key",
        "errors": {"key": ["give a person with a handle a key"]}}
      """
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "emails": [{"value": "not an address"}]}
      """
    Then the API answer holds "{\"emails\":[\"an email address looks like ada@example.com\"]}"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "birthday": "December"}
      """
    Then the API answer holds "{\"birthday\":[\"a birthday looks like 1815-12-10, or --12-10 without the year\"]}"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "birthday": "1815-13-10"}
      """
    Then the API answer holds "{\"birthday\":[\"a birthday looks like 1815-12-10, or --12-10 without the year\"]}"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "birthday": "12/10/1815"}
      """
    Then the API answer holds "{\"birthday\":[\"a birthday looks like 1815-12-10, or --12-10 without the year\"]}"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "birthday": "--7-8"}
      """
    Then the API answer holds "{\"birthday\":[\"a birthday looks like 1815-12-10, or --12-10 without the year\"]}"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "key": "ada lovelace", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the API answer holds "{\"key\":[\"a key is lowercase words joined by hyphens\"]}"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "key": "grace", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the API answer holds "{\"key\":[\"someone else already holds that key\"]}"
    When I POST "/people" through the API with:
      """
      {"name": " ", "key": "ada", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the API answer holds "{\"name\":[\"give the person a name\"]}"
    When I POST "/people" through the API with:
      """
      {"name": "A\u0000da", "key": "ada", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the API answer holds "{\"name\":[\"name holds a control character\"]}"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "key": "ada", "mastodon_handle": "ada@ruby.social"}
      """
    Then the API answer holds "{\"mastodon_handle\":[\"a Mastodon handle looks like @ada@ruby.social\"]}"
    And the contacts are "Grace"

  Scenario: The API refuses a Bluesky handle Bluesky does not know or while it does not answer
    Given an API token with the scopes "read write delete contacts"
    And Bluesky knows no account by the handle "nobody.bsky.social"
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "key": "ada", "bluesky_handle": "nobody.bsky.social"}
      """
    Then the API answer holds "{\"bluesky_handle\":[\"Bluesky knows no account by that handle\"]}"
    Given Bluesky's app view answers GET "/xrpc/com.atproto.identity.resolveHandle" with status 502
    When I POST "/people" through the API with:
      """
      {"name": "Ada", "key": "ada", "bluesky_handle": "ada.bsky.social"}
      """
    Then the API answer holds "{\"bluesky_handle\":[\"Bluesky did not answer; try again in a moment\"]}"
    And there are no contacts

  Scenario: The API edits what it is given and keeps the rest
    Given an API token with the scopes "read write delete contacts"
    And a contact "Ada" with:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social", "bluesky_handle": "ada.bsky.social",
        "bluesky_did": "did:plc:ada"}
      """
    And a contact "Grace" with:
      """
      {"key": "grace"}
      """
    When I call the people API with PATCH "/people/:id" for "Ada" and:
      """
      {"name": "Ada Lovelace", "bluesky_handle": "ada.bsky.social"}
      """
    Then the API person "Ada Lovelace" holds:
      """
      {"key": "ada", "bluesky_handle": "ada.bsky.social"}
      """
    And the contact "Ada Lovelace" holds:
      """
      {"bluesky_did": "did:plc:ada"}
      """
    When I call the people API with PATCH "/people/:id" for "Ada Lovelace" and:
      """
      {"notes": "Wrote the first program"}
      """
    Then the API person "Ada Lovelace" holds:
      """
      {"notes": "Wrote the first program"}
      """
    When I call the people API with PATCH "/people/:id" for "Ada Lovelace" and:
      """
      {"key": "grace"}
      """
    Then the API answer holds "{\"key\":[\"someone else already holds that key\"]}"
    When I call the people API with PATCH "/people/:id" for "Ada Lovelace" and:
      """
      {"bluesky_handle": null}
      """
    Then the contact "Ada Lovelace" holds:
      """
      {"bluesky_handle": null, "bluesky_did": null, "mastodon_handle": "@ada@ruby.social"}
      """
    When I call the people API with PATCH "/people/:id" for "Ada Lovelace" and:
      """
      {"mastodon_handle": null}
      """
    Then the contact "Ada Lovelace" holds:
      """
      {"key": "ada", "mastodon_handle": null, "bluesky_handle": null}
      """

  Scenario: The API refuses an edit that leaves a person without a name or a key
    Given an API token with the scopes "read write delete contacts"
    And a contact "Grace"
    When I call the people API with PATCH "/people/:id" for "Grace" and:
      """
      {"name": " "}
      """
    Then the API answers 422
    And the API answer holds "give the person a name"
    When I call the people API with PATCH "/people/:id" for "Grace" and:
      """
      {"mastodon_handle": "@grace@ruby.social"}
      """
    Then the API answer holds "give a person with a handle a key"

  Scenario: The API lets a token without contacts edit only the open fields
    Given an API token with the scopes "read write delete"
    And a contact "Ada" with:
      """
      {"key": "ada"}
      """
    When I call the people API with PATCH "/people/:id" for "Ada" and:
      """
      {"name": "Ada Lovelace", "notes": "Wrote the first program"}
      """
    Then the API answers 403
    And the contact "Ada" holds:
      """
      {"notes": null}
      """
    When I call the people API with PATCH "/people/:id" for "Ada" and:
      """
      {"name": "Ada Lovelace"}
      """
    Then the API person "Ada Lovelace" holds:
      """
      {"key": "ada"}
      """

  Scenario: The API deletes a person only with the contacts scope
    Given an API token with the scopes "read write delete"
    And a contact "Ada"
    When I call the people API with DELETE "/people/:id" for "Ada"
    Then the API answers 403
    And the contacts are "Ada"
    Given an API token with the scopes "read write delete contacts"
    When I call the people API with DELETE "/people/:id" for "Ada"
    Then the API answers 200
    And the API answer gives the contact "Ada" as deleted
    And there are no contacts

  Scenario: The API queues a contact sync only with the contacts scope
    Given an API token with the scopes "read write"
    When I POST "/people/sync" through the API with:
      """
      {}
      """
    Then the API answers 403
    Given an API token with the scopes "read write contacts"
    When I POST "/people/sync" through the API with:
      """
      {}
      """
    Then the API answer is exactly:
      """
      {"status": "queued"}
      """

  Scenario: The API sends a contact linked to Google through Google
    Given an API token with the scopes "read write delete contacts"
    And the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers POST "/people:createContact" with:
      """
      {"resourceName": "people/c9", "etag": "e1", "names": [{"displayName": "Ada", "metadata": {"primary": true}}]}
      """
    When I POST "/people" through the API with:
      """
      {"name": "Ada"}
      """
    Then the contact "Ada" is now linked to Google as "c9" under "me@example.com"
    And the contact "Ada" holds:
      """
      {"google_etag": "e1"}
      """
    When I call the people API with PATCH "/people/:id" for "Ada" and:
      """
      {"key": "ada"}
      """
    Then the API answers 200
    And Google People received no GET "/people/c9"
    Given Google People answers GET "/people/c9" with:
      """
      {"resourceName": "people/c9", "etag": "e1", "names": [{"displayName": "Ada", "metadata": {"primary": true}}]}
      """
    And Google People answers PATCH "/people/c9:updateContact" with:
      """
      {"resourceName": "people/c9", "etag": "e2", "names": [{"displayName": "Ada King", "metadata": {"primary": true}}]}
      """
    When I call the people API with PATCH "/people/:id" for "Ada" and:
      """
      {"name": "Ada King"}
      """
    Then Google People received PATCH "/people/c9:updateContact" holding "\"names\":[{\"unstructuredName\":\"Ada King\"}]"
    Given Google People answers DELETE "/people/c9:deleteContact" with:
      """
      {}
      """
    When I call the people API with DELETE "/people/:id" for "Ada King"
    Then Google People received DELETE "/people/c9:deleteContact"
    And there are no contacts

  Scenario: The API creates an unmatched local person in Google when it is next edited
    Given an API token with the scopes "read write delete contacts"
    And a contact "Ada"
    And the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers POST "/people:createContact" with:
      """
      {"resourceName": "people/c1", "etag": "e1", "names": [{"displayName": "Ada", "metadata": {"primary": true}}]}
      """
    When I call the people API with PATCH "/people/:id" for "Ada" and:
      """
      {"nickname": "Countess"}
      """
    Then Google People received POST "/people:createContact" holding "\"nicknames\":[{\"value\":\"Countess\"}]"
    And the contact "Ada" is now linked to Google as "c1" under "me@example.com"

  Scenario: The API refuses an edit Google changed first and a delete Google refuses
    Given an API token with the scopes "read write delete contacts"
    And the Google account "me@example.com" is connected with "contacts"
    And a contact "Ada" with:
      """
      {"key": "ada"}
      """
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers GET "/people/c1" with:
      """
      {"resourceName": "people/c1", "etag": "e2", "names": [{"displayName": "Ada King", "metadata": {"primary": true}}]}
      """
    And Google People answers DELETE "/people/c1:deleteContact" with status 500
    When I call the people API with PATCH "/people/:id" for "Ada" and:
      """
      {"name": "Ada Lovelace"}
      """
    Then the API answers 409
    And the API answer is exactly:
      """
      {"error": "conflict",
        "message": "Google changed this contact first, so nothing changed; read it again and redo the edit"}
      """
    And Google People received no PATCH "/people/c1:updateContact"
    When I call the people API with DELETE "/people/:id" for "Ada King"
    Then the API answers 503
    And the API answer is exactly:
      """
      {"error": "unavailable", "message": "Google did not take the change, so nothing changed; try again soon"}
      """
    And the contacts are "Ada King"

  Scenario: The API deletes a contact Google already deleted
    Given an API token with the scopes "read write delete contacts"
    And the Google account "me@example.com" is connected with "contacts"
    And a contact "Ada"
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers DELETE "/people/c1:deleteContact" with status 404
    When I call the people API with DELETE "/people/:id" for "Ada"
    Then the API answers 200
    And there are no contacts

  Scenario: The API searches Mastodon and Bluesky as the admin does
    Given an API token with the scopes "read write delete contacts"
    And the admin can search people on "Mastodon and Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with:
      """
      {"actors": [{"avatar": "https://203.0.113.20/ada.jpg", "displayName": "Ada Lovelace", "handle": "ada.bsky.social"}]}
      """
    And Mastodon answers GET "/203.0.113.5/api/v2/search" with:
      """
      {"accounts": [{"acct": "grace@hachyderm.io", "avatar": null, "display_name": "Grace Hopper"}]}
      """
    When I GET "/people/search/bluesky?query=ada" through the API
    Then the API answer is exactly:
      """
      {"accounts": [{"handle": "ada.bsky.social", "name": "Ada Lovelace", "avatar": "https://203.0.113.20/ada.jpg"}]}
      """
    When I GET "/people/search/mastodon?query=grace" through the API
    Then the API answer is exactly:
      """
      {"accounts": [{"handle": "@grace@hachyderm.io", "name": "Grace Hopper", "avatar": null}]}
      """

  Scenario: The API search asks no network for a query shorter than two characters
    Given an API token with the scopes "read write delete contacts"
    And the admin can search people on "Bluesky"
    When I GET "/people/search/bluesky?query=%20a%20" through the API
    Then the API answer is exactly:
      """
      {"accounts": []}
      """
    And Bluesky's app view received no GET "/xrpc/app.bsky.actor.searchActorsTypeahead"

  Scenario: The API search refuses a network it cannot reach
    Given an API token with the scopes "read write delete contacts"
    And the admin can search people on "Mastodon"
    And Mastodon answers GET "/203.0.113.5/api/v2/search" with status 429
    When I GET "/people/search/bluesky?query=ada" through the API
    Then the API answers 503
    And the API answer is exactly:
      """
      {"error": "unavailable", "message": "Bluesky has no credentials, so it cannot be searched"}
      """
    When I GET "/people/search/mastodon?query=grace" through the API
    Then the API answers 503
    And the API answer is exactly:
      """
      {"error": "unavailable", "message": "Mastodon has had too many searches; wait a minute and try again"}
      """
    When I GET "/people/search/myspace?query=ada" through the API
    Then the API answers 422
    When I GET "/openapi.json" through the API
    Then the OpenAPI document lists "503" for the people search

  Scenario: The API search refuses a network that does not answer
    Given an API token with the scopes "read write delete contacts"
    And the admin can search people on "Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with status 502
    When I GET "/people/search/bluesky?query=ada" through the API
    Then the API answer holds "Bluesky did not answer; try again"
