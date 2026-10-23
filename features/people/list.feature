Feature: The contacts list
  The Contacts tab lists everyone, finds them by any field and filters by
  show and label.

  Background:
    Given I am signed in to the admin

  Scenario: An empty contacts list says who to add and that Google has not synced
    When I visit "/admin/contacts"
    Then I see "Nobody yet. Sync Google Contacts or add someone."
    And I see "0 contacts, synced both ways with Google Contacts · not synced yet."
    And the contact page links "New contact" to "/admin/contacts/new"
    And I see "Sync now"
    And the page has no axe breaches in light or dark

  Scenario: The contacts list draws each row in file-as order
    Given a contact "Grace Hopper"
    And a contact "Ada Lovelace" with:
      """
      {"given_name": "Ada", "family_name": "Lovelace", "file_as": "Lovelace, Ada", "starred": true,
        "job_title": "Analyst", "company": "Engines", "key": "ada", "mastodon_handle": "@ada@ruby.social",
        "labels": ["family", "speaking"],
        "emails": [{"value": "ada@example.com"}, {"value": "ada@work.example"}]}
      """
    And a contact with:
      """
      {"company": "Babbage & Co"}
      """
    And a contact "zed"
    When I visit "/admin/contacts"
    Then the contacts list names "Babbage & Co, Grace Hopper, Ada Lovelace, zed"
    And I see "4 contacts, synced both ways with Google Contacts"
    And the contact row "Ada Lovelace" shows "AL"
    And the contact row "Ada Lovelace" is starred
    And the contact row "Ada Lovelace" shows "Analyst · Engines"
    And the contact row "Ada Lovelace" shows "ada@example.com+1"
    And the contact row "Ada Lovelace" links to "mailto:ada@example.com"
    And the contact row "Ada Lovelace" links to "https://ruby.social/@ada"
    And the contact row "Ada Lovelace" shows "#family#speaking"
    And the contact row "Ada Lovelace" edits from its pencil
    And the contact row "Ada Lovelace" offers a menu
    And the contact row "Grace Hopper" shows "no email"
    And the contact row "zed" shows "ZE"
    And the page has no axe breaches in light or dark
    When I open the contact "Ada Lovelace" from the list
    Then the contact header reads "Ada Lovelace"

  Scenario: The contacts tab counts its contacts and sits after webmentions
    Given a contact "Ada Lovelace"
    And a contact "Grace Hopper"
    When I visit "/admin/contacts"
    Then the contacts tab counts 2
    And the admin tabs end with webmentions then contacts
    And the command palette offers the contacts
    And the contacts address "/admin/people" sends me to "/admin/contacts"
    And the contacts address "/admin/people/new" sends me to "/admin/contacts/new"
    When I visit "/admin/settings/webmentions"
    Then I do not see "Ada Lovelace"

  Scenario: The contacts list finds a contact by any field but an email type
    Given a contact "Ada Lovelace" with:
      """
      {"nickname": "Countess", "key": "ada", "company": "Engines", "job_title": "Analyst",
        "mastodon_handle": "@ada@ruby.social", "emails": [{"value": "ada@example.com"}],
        "phones": [{"value": "+44 20 7946 0000"}]}
      """
    And a contact "Grace Hopper"
    And a contact "Alan Turing" with:
      """
      {"emails": [{"value": "alan@example.com", "type": "work"}]}
      """
    When I visit "/admin/contacts?q=lovelace"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?q=countess"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?q=ada"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?q=engines"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?q=analyst"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?q=ruby.social"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?q=ada@example"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?q=7946"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?q=work"
    Then I see "No contacts match."
    When I visit "/admin/contacts?q=nobody"
    Then I see "No contacts match."

  Scenario: The contacts list filters by show and label and keeps them in its links
    Given a contact "Ada Lovelace" with:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social", "labels": ["family"], "starred": true}
      """
    And a contact "Grace Hopper" with:
      """
      {"labels": ["navy"]}
      """
    When I visit "/admin/contacts?show=starred"
    Then the contacts list names "Ada Lovelace"
    And the contacts show "starred" is marked
    When I visit "/admin/contacts?show=mentionable"
    Then the contacts list names "Ada Lovelace"
    When I visit "/admin/contacts?show=bogus"
    Then the contacts list names "Ada Lovelace, Grace Hopper"
    When I visit "/admin/contacts?label=navy"
    Then the contacts list names "Grace Hopper"
    When I visit "/admin/contacts?q=a&label=family"
    Then the contacts show "all" links to "/admin/contacts?q=a&label=family"
    And the contacts show "starred" links to "/admin/contacts?q=a&show=starred&label=family"
    And the contacts show "mentionable" links to "/admin/contacts?q=a&show=mentionable&label=family"
    And the contacts label "#family" is marked
    And the contacts label "#family" links to "/admin/contacts?q=a"
    And the contacts label "#navy" links to "/admin/contacts?q=a&label=navy"
    When I visit "/admin/contacts?show=starred&label=family"
    Then the contacts search keeps "show" as "starred"
    And the contacts search keeps "label" as "family"

  Scenario: The contacts list searches as I type and filters from a label pill
    Given a contact "Ada Lovelace" with:
      """
      {"key": "ada", "labels": ["family"]}
      """
    And a contact "Grace Hopper" with:
      """
      {"key": "grace"}
      """
    When I visit "/admin/contacts"
    And I type "grace" in the contacts search
    Then the contacts list names "Grace Hopper"
    When I visit "/admin/contacts"
    And I click "#family"
    Then the contacts list names "Ada Lovelace"
