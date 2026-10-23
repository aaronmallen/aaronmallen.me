Feature: Contacts saved to Google
  With a Google account that takes new contacts, the editor sends each new
  contact, edit and delete to Google Contacts, and keeps nothing Google
  refused.

  Background:
    Given I am signed in to the admin
    And the Google account "me@example.com" is connected with "contacts"
    And the Google account "me@example.com" syncs contacts
    And Google People answers GET "/contactGroups" with:
      """
      {"contactGroups": [{"resourceName": "contactGroups/abc", "name": "family", "groupType": "USER_CONTACT_GROUP"}]}
      """

  Scenario: Adding a contact creates it in Google under that account and links it
    Given Google People answers POST "/people:createContact" with:
      """
      {"resourceName": "people/c1", "etag": "e1",
        "names": [{"displayName": "Ada Lovelace", "givenName": "Ada", "familyName": "Lovelace", "metadata": {"primary": true}}],
        "urls": [{"value": "https://ruby.social/@ada", "type": "Mastodon"}]}
      """
    When I visit "/admin/contacts/new"
    And I fill in the contact field "First" with "Ada"
    And I fill in the contact field "Last" with "Lovelace"
    And I fill in the contact field "Birthday" with "1815-12-10"
    And I fill in the contact field "Mastodon" with "@ada@ruby.social"
    And I fill in the contact field "Mention key" with "ada"
    And I add the contact row "Emails" as "ada@example.com"
    And I add the contact address in "London"
    And I submit the contact form with "Add contact"
    Then I see "Contact added"
    And Google People received POST "/people:createContact" holding "\"emailAddresses\":[{\"value\":\"ada@example.com\",\"type\":\"home\"}]"
    And Google People received POST "/people:createContact" holding "\"city\":\"London\""
    And Google People received POST "/people:createContact" holding "\"birthdays\":[{\"date\":{\"year\":1815,\"month\":12,\"day\":10}}]"
    And Google People received POST "/people:createContact" holding "\"urls\":[{\"value\":\"https://ruby.social/@ada\",\"type\":\"Mastodon\"}]"
    And the contact "Ada Lovelace" is now linked to Google as "c1" under "me@example.com"
    And the contact "Ada Lovelace" holds:
      """
      {"google_etag": "e1", "websites": [], "mastodon_handle": "@ada@ruby.social"}
      """

  Scenario: Adding a contact saves nothing when Google refuses it
    Given Google People answers POST "/people:createContact" with status 500
    When I visit "/admin/contacts/new"
    And I fill in the contact field "First" with "Ada"
    And I submit the contact form with "Add contact"
    Then I see "Google didn't take that, so nothing changed. Try again in a moment."
    And the contact field "First" holds "Ada"
    And there are no contacts

  Scenario: Editing a contact linked to Google updates it there, labels and star included
    Given a contact "Ada" with:
      """
      {"given_name": "Ada", "key": "ada"}
      """
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers GET "/people/c1" with:
      """
      {"resourceName": "people/c1", "etag": "e1", "names": [{"displayName": "Ada", "metadata": {"primary": true}}]}
      """
    And Google People answers POST "/contactGroups" with:
      """
      {"resourceName": "contactGroups/new"}
      """
    And Google People answers PATCH "/people/c1:updateContact" with:
      """
      {"resourceName": "people/c1", "etag": "e2", "names": [{"displayName": "Ada", "givenName": "Ada", "metadata": {"primary": true}}],
        "memberships": [{"contactGroupMembership": {"contactGroupResourceName": "contactGroups/abc"}},
                        {"contactGroupMembership": {"contactGroupResourceName": "contactGroups/new"}},
                        {"contactGroupMembership": {"contactGroupResourceName": "contactGroups/starred"}}]}
      """
    When I edit the contact "Ada"
    And I add the new contact label "family"
    And I add the new contact label "speaking"
    And I star the contact in the form
    And I submit the contact form with "Save"
    Then I see "Contact saved"
    And Google People received POST "/contactGroups" holding "speaking"
    And Google People received PATCH "/people/c1:updateContact" holding "\"etag\":\"e1\""
    And Google People received PATCH "/people/c1:updateContact" holding "contactGroups/starred"
    And Google People received PATCH "/people/c1:updateContact" holding "contactGroups/new"
    And the contact "Ada" holds:
      """
      {"labels": ["family", "speaking"], "starred": true, "google_etag": "e2"}
      """

  Scenario: Editing a contact Google changed first loads Google's version on the editor
    Given a contact "Ada" with:
      """
      {"given_name": "Ada", "key": "ada"}
      """
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers GET "/people/c1" with:
      """
      {"resourceName": "people/c1", "etag": "e2",
        "names": [{"displayName": "Ada King", "givenName": "Ada", "familyName": "King", "metadata": {"primary": true}}]}
      """
    When I edit the contact "Ada"
    And I fill in the contact field "Nickname" with "Countess"
    And I submit the contact form with "Save"
    Then I see "Google changed this contact first. This is its version now, so make your edit again."
    And the contact field "Last" holds "King"
    And the contact field "Nickname" holds ""
    And the contact "Ada King" holds:
      """
      {"google_etag": "e2"}
      """
    And Google People received no PATCH "/people/c1:updateContact"

  Scenario: Editing a contact keeps the typed edit on the editor when Google refuses it
    Given a contact "Ada" with:
      """
      {"given_name": "Ada", "key": "ada"}
      """
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers GET "/people/c1" with:
      """
      {"resourceName": "people/c1", "etag": "e1", "names": [{"displayName": "Ada", "metadata": {"primary": true}}]}
      """
    And Google People answers PATCH "/people/c1:updateContact" with status 500
    When I edit the contact "Ada"
    And I fill in the contact field "Nickname" with "Countess"
    And I submit the contact form with "Save"
    Then I see "Google didn't take that, so nothing changed. Try again in a moment."
    And the contact field "Nickname" holds "Countess"
    And the contact "Ada" holds:
      """
      {"nickname": null}
      """

  Scenario: Deleting a contact linked to Google deletes it there too
    Given a contact "Ada"
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers DELETE "/people/c1:deleteContact" with:
      """
      {}
      """
    When I edit the contact "Ada"
    And I click the contact button "Delete"
    And I confirm the contact delete
    Then I see "Contact deleted"
    And Google People received DELETE "/people/c1:deleteContact"
    And there are no contacts

  Scenario: Deleting a contact Google already deleted deletes it here
    Given a contact "Ada"
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers DELETE "/people/c1:deleteContact" with status 404
    When I edit the contact "Ada"
    And I click the contact button "Delete"
    And I confirm the contact delete
    Then I see "Contact deleted"
    And there are no contacts

  Scenario: Deleting a contact keeps it and says so when Google refuses
    Given a contact "Ada"
    And the contact "Ada" is linked to Google as "c1" under "me@example.com"
    And Google People answers DELETE "/people/c1:deleteContact" with status 500
    When I edit the contact "Ada"
    And I click the contact button "Delete"
    And I confirm the contact delete
    Then I see "Google didn't take that, so nothing changed. Try again in a moment."
    And the contacts are "Ada"

  Scenario: Deleting a contact Google does not hold asks Google nothing
    Given a contact "Ada"
    When I edit the contact "Ada"
    And I click the contact button "Delete"
    And I confirm the contact delete
    Then I see "Contact deleted"
    And there are no contacts
