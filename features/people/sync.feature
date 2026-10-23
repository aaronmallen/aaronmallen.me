Feature: Contact sync with Google
  The contacts sync job reads each opted-in Google account's address book,
  keeps every field Google holds and then asks only for what changed.

  Scenario: The first contacts sync keeps every field Google holds
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": [{"resourceName": "contactGroups/abc", "name": "speaking", "groupType": "USER_CONTACT_GROUP"},
                          {"resourceName": "contactGroups/myContacts", "name": "myContacts", "groupType": "SYSTEM_CONTACT_GROUP"}]}
      """
    And Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "first", "connections": [
        {"resourceName": "people/c1", "etag": "e1",
          "names": [{"displayName": "Ada Lovelace", "givenName": "Ada", "familyName": "Lovelace", "honorificPrefix": "Countess", "metadata": {"primary": true}}],
          "nicknames": [{"value": "Ada"}], "fileAses": [{"value": "Lovelace, Ada"}],
          "organizations": [{"name": "Analytical Engines", "title": "Analyst", "department": "Notes"}],
          "biographies": [{"value": "Wrote the first program"}],
          "emailAddresses": [{"value": "ada@example.com", "type": "work"}, {"value": " "}],
          "phoneNumbers": [{"value": "+44 20 7946 0000", "type": "mobile"}],
          "addresses": [{"streetAddress": "12 St James's Square", "city": "London", "country": "UK", "type": "home"}, {}],
          "urls": [{"value": "https://ruby.social/@ada", "type": "Mastodon"},
                  {"value": "https://bsky.app/profile/ada.bsky.social", "type": "Bluesky"},
                  {"value": "https://ada.example.com", "type": "blog"}],
          "imClients": [{"username": "ada", "protocol": "jabber", "formattedProtocol": "Jabber"}],
          "birthdays": [{"date": {"year": 1815, "month": 12, "day": 10}}],
          "events": [{"date": {"month": 6, "day": 8}, "type": "anniversary"}, {"date": {"year": 1840}}],
          "relations": [{"person": "Byron", "type": "father"}],
          "userDefined": [{"key": "Engine", "value": "Difference"}],
          "memberships": [{"contactGroupMembership": {"contactGroupResourceName": "contactGroups/starred"}},
                          {"contactGroupMembership": {"contactGroupResourceName": "contactGroups/abc"}},
                          {"contactGroupMembership": {"contactGroupResourceName": "contactGroups/myContacts"}}]},
        {"resourceName": "people/c2", "names": [{"displayName": "Grace Hopper", "metadata": {"primary": true}}], "memberships": []},
        {"resourceName": "people/c8", "organizations": [{"name": "Acme"}]},
        {"resourceName": "people/c9", "emailAddresses": [{"value": "x@example.com"}]}
      ]}
      """
    When the contacts sync job runs
    Then the contacts sync token for "me@example.com" is "first"
    And the contact "Ada Lovelace" is now linked to Google as "c1" under "me@example.com"
    And the contact "Ada Lovelace" holds:
      """
      {"google_etag": "e1", "given_name": "Ada", "family_name": "Lovelace", "name_prefix": "Countess",
        "nickname": "Ada", "file_as": "Lovelace, Ada", "company": "Analytical Engines", "job_title": "Analyst",
        "department": "Notes", "notes": "Wrote the first program",
        "emails": [{"value": "ada@example.com", "type": "work"}],
        "phones": [{"value": "+44 20 7946 0000", "type": "mobile"}],
        "addresses": [{"street": "12 St James's Square", "city": "London", "country": "UK", "type": "home"}],
        "websites": [{"value": "https://ada.example.com", "type": "blog"}],
        "chats": [{"value": "ada", "type": "Jabber"}], "birthday": "1815-12-10",
        "dates": [{"value": "--06-08", "type": "anniversary"}],
        "relations": [{"value": "Byron", "type": "father"}],
        "custom_fields": [{"key": "Engine", "value": "Difference"}],
        "labels": ["speaking"], "starred": true}
      """
    And the contact "Grace Hopper" holds:
      """
      {"labels": [], "starred": false}
      """
    And the contact "Acme" holds:
      """
      {"name": null, "company": "Acme"}
      """
    And the contacts are "Acme, Ada Lovelace, Grace Hopper"
    And the contacts sync records no failure
    Given I am signed in to the admin
    When I visit "/admin/contacts"
    Then I see "last synced"

  Scenario: The next contacts sync takes only what changed and keeps the key and handles stored here
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "first", "connections": [
        {"resourceName": "people/c1", "names": [{"displayName": "Ada Lovelace", "metadata": {"primary": true}}]},
        {"resourceName": "people/c2", "names": [{"displayName": "Grace Hopper", "metadata": {"primary": true}}]},
        {"resourceName": "people/c4", "names": [{"displayName": "Dorothy Vaughan", "metadata": {"primary": true}}]}
      ]}
      """
    When the contacts sync job runs
    Then the contacts sync token for "me@example.com" is "first"
    Given the contact "Ada Lovelace" gets:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social"}
      """
    And Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "second", "connections": [
        {"resourceName": "people/c1", "names": [{"displayName": "Ada King", "metadata": {"primary": true}}],
          "urls": [{"value": "https://mastodon.social/@ada", "type": "Mastodon"}]},
        {"resourceName": "people/c2", "metadata": {"deleted": true}},
        {"resourceName": "people/c3", "names": [{"displayName": "Katherine Johnson", "metadata": {"primary": true}}]}
      ]}
      """
    When the contacts sync job runs
    Then the contacts sync token for "me@example.com" is "second"
    And the contacts are "Ada King, Dorothy Vaughan, Katherine Johnson"
    And the contact "Ada King" holds:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social", "websites": []}
      """

  Scenario: The next contacts sync tries the whole address book once, then records the failure
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "first", "connections": [
        {"resourceName": "people/c1", "names": [{"displayName": "Ada Lovelace", "metadata": {"primary": true}}]}
      ]}
      """
    When the contacts sync job runs
    Then the contacts sync token for "me@example.com" is "first"
    Given Google People answers GET "/people/me/connections" with status 503
    When the contacts sync job runs
    Then the contacts sync records the failure "google_contacts_failed: Google answered 503"
    And Google was asked for the contacts 3 times
    And the contacts are "Ada Lovelace"
    Given I am signed in to the admin
    When I visit "/admin/contacts"
    Then I see "the last sync failed."

  Scenario: A first contacts sync that Google fails records the failure and keeps no token
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And Google People answers GET "/people/me/connections" with status 503
    When the contacts sync job runs
    Then the contacts sync records the failure "google_contacts_failed: Google answered 503"
    And the contacts sync keeps no token

  Scenario: The contacts sync leaves alone an account that has not opted in or lacks the contacts scope
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "health@example.com" is connected with "googlehealth.sleep.readonly"
    And the Google account "health@example.com" syncs contacts
    And a contact "Ada Lovelace" with:
      """
      {"key": "local"}
      """
    And the contacts sync last failed
    When the contacts sync job runs
    Then the contacts sync failure clears
    And Google was not asked for contacts
    And the contacts are "Ada Lovelace"

  Scenario: The contacts sync steps aside while another run holds the lock
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And the contacts sync last failed
    And another contacts sync holds the lock
    When the contacts sync job runs beside it
    Then Google was not asked for contacts
    And the contacts sync still records the failure "crashed: boom"

  Scenario: The contacts sync keeps a person no Google account holds
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And a contact "Ada Lovelace" with:
      """
      {"key": "local"}
      """
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "first", "connections": []}
      """
    When the contacts sync job runs
    Then the contacts sync token for "me@example.com" is "first"
    And the contact keyed "local" is not linked to Google
    And the contacts are "Ada Lovelace"

  Scenario: The contacts sync keeps each account's copy of a contact apart
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And the Google account "other@example.com" is connected with "contacts"
    And the Google account "other@example.com" syncs contacts without taking new ones
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "first", "connections": [
        {"resourceName": "people/c1", "names": [{"displayName": "Ada Lovelace", "metadata": {"primary": true}}]}
      ]}
      """
    When the contacts sync job runs
    Then the contacts sync token for "me@example.com" is "first"
    And the contacts sync token for "other@example.com" is "first"
    And each Google account holds a copy of "Ada Lovelace"

  Scenario: The first contacts sync links the people already here by email, profile link or name
    Given the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And a contact "Countess" with:
      """
      {"key": "ada", "emails": [{"value": "Ada@Example.com"}]}
      """
    And a contact "Babbage" with:
      """
      {"key": "charles", "mastodon_handle": "@charles@ruby.social"}
      """
    And a contact "Mary" with:
      """
      {"key": "mary", "bluesky_handle": "mary.bsky.social", "bluesky_did": "did:plc:mary"}
      """
    And a contact "Grace Hopper" with:
      """
      {"key": "grace", "mastodon_handle": "@grace@ruby.social"}
      """
    And a contact "Katherine Johnson" with:
      """
      {"key": "named"}
      """
    And a contact "Kate" with:
      """
      {"key": "emailed", "emails": [{"value": "kj@example.com"}]}
      """
    And a contact "Alan Turing" with:
      """
      {"key": "alan"}
      """
    And a contact "Hedy Lamarr" with:
      """
      {"key": "hedy", "emails": [{"value": "hedy@example.com"}]}
      """
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "first", "connections": [
        {"resourceName": "people/c1", "names": [{"displayName": "Ada Lovelace", "metadata": {"primary": true}}],
          "emailAddresses": [{"value": "ada@example.com"}]},
        {"resourceName": "people/c2", "names": [{"displayName": "Charles Babbage", "metadata": {"primary": true}}],
          "urls": [{"value": "https://Ruby.social/@charles/", "type": "profile"}]},
        {"resourceName": "people/c3", "names": [{"displayName": "Mary Somerville", "metadata": {"primary": true}}],
          "urls": [{"value": "https://bsky.app/profile/mary.bsky.social"}]},
        {"resourceName": "people/c4", "names": [{"displayName": "Grace Hopper", "metadata": {"primary": true}}]},
        {"resourceName": "people/c5", "names": [{"displayName": "Katherine Johnson", "metadata": {"primary": true}}],
          "emailAddresses": [{"value": "kj@example.com"}]},
        {"resourceName": "people/c6", "names": [{"displayName": "Alan Turing", "metadata": {"primary": true}}]},
        {"resourceName": "people/c7", "names": [{"displayName": "Alan Turing", "metadata": {"primary": true}}]}
      ]}
      """
    When the contacts sync job runs
    Then the contacts sync token for "me@example.com" is "first"
    And the contact keyed "ada" is linked to Google as "c1"
    And the contact keyed "ada" holds:
      """
      {"name": "Ada Lovelace"}
      """
    And the contact keyed "charles" is linked to Google as "c2"
    And the contact keyed "mary" is linked to Google as "c3"
    And the contact keyed "grace" is linked to Google as "c4"
    And the contact keyed "grace" holds:
      """
      {"key": "grace", "mastodon_handle": "@grace@ruby.social"}
      """
    And the contact keyed "emailed" is linked to Google as "c5"
    And the contact keyed "named" is not linked to Google
    And 2 contacts are named "Alan Turing"
    And the contact keyed "hedy" is not linked to Google
    And the contact keyed "hedy" holds:
      """
      {"name": "Hedy Lamarr"}
      """
    Given Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "next", "connections": [
        {"resourceName": "people/c8", "names": [{"displayName": "Hedy Lamarr", "metadata": {"primary": true}}]}
      ]}
      """
    When the contacts sync job runs
    Then the contacts sync token for "me@example.com" is "next"
    And 2 contacts are named "Hedy Lamarr"
    And the contact keyed "hedy" is not linked to Google

  Scenario: Sync now queues the same job the schedule runs and lands back on the contacts
    Given I am signed in to the admin
    And the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": []}
      """
    And Google People answers GET "/people/me/connections" with:
      """
      {"nextSyncToken": "first", "connections": [
        {"resourceName": "people/c1", "names": [{"displayName": "Ada Lovelace", "metadata": {"primary": true}}]}
      ]}
      """
    When I visit "/admin/contacts"
    And I click the contact button "Sync now"
    Then I see "Contact sync queued · Google's changes land in a moment"
    And the browser is on the contacts list
    And the contacts are "Ada Lovelace"

  Scenario: Each Google account has its own contact sync options
    Given I am signed in to the admin
    And the Google account "me@example.com" is connected with "openid"
    And the Google account "work@example.com" is connected with "openid"
    When I open the Google account "me@example.com" in the services settings
    Then the contact switch "Sync contacts" is off
    And the contact switch "Save new contacts here" waits on the first
    And I see "Google Contacts sync"
    When I flip the contact switch "Sync contacts"
    Then I see "me@example.com syncs its contacts"
    And the Google account "me@example.com" syncs contacts yes and saves new ones no
    And the Google account "work@example.com" syncs contacts no and saves new ones no
    When I flip the contact switch "Save new contacts here"
    Then I see "me@example.com syncs its contacts and takes new ones"
    When I open the Google account "work@example.com" in the services settings
    And I flip the contact switch "Sync contacts"
    And I flip the contact switch "Save new contacts here"
    Then I see "work@example.com syncs its contacts and takes new ones"
    And the Google account "me@example.com" syncs contacts yes and saves new ones no
    And the Google account "work@example.com" syncs contacts yes and saves new ones yes
    When I flip the contact switch "Sync contacts"
    Then I see "work@example.com no longer syncs contacts"
    And the Google account "work@example.com" syncs contacts no and saves new ones no

  Scenario: Contact sync options answer not found for an account that is not Google
    Given I am signed in to the admin
    And a GitHub service connection with no contacts
    When I post contact options for the GitHub connection
    Then the contact options answer 404
