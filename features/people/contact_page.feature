Feature: The contact page
  Each contact has a page that shows every field, the mail with them and
  what Google holds.

  Background:
    Given I am signed in to the admin

  Scenario: The contact page shows every field a contact holds
    Given a contact "Ada Lovelace" with:
      """
      {"given_name": "Ada", "family_name": "Lovelace", "key": "ada", "mastodon_handle": "@ada@ruby.social",
        "bluesky_handle": "ada.bsky.social", "bluesky_did": "did:plc:ada", "nickname": "Countess",
        "company": "Engines", "job_title": "Analyst", "department": "Notes", "birthday": "1815-12-10",
        "emails": [{"value": "ada@example.com", "type": "home"}],
        "phones": [{"value": "+44 20 7946 0000", "type": "mobile"}],
        "addresses": [{"street": "12 St James's Square", "city": "London", "country": "UK"}],
        "websites": [{"value": "https://ada.example"}, {"value": "javascript:alert(1)"}],
        "chats": [{"value": "ada", "type": "Jabber"}], "dates": [{"value": "--07-08", "type": "anniversary"}],
        "relations": [{"value": "William King", "type": "spouse"}],
        "custom_fields": [{"key": "Engine", "value": "Analytical"}], "notes": "the first program",
        "labels": ["family"], "file_as": "Lovelace, Ada"}
      """
    When I open the contact "Ada Lovelace"
    Then the contact header reads "AL"
    And the contact header reads "Ada Lovelace"
    And the contact header reads "Analyst · Notes · Engines"
    And the contact header reads "#family"
    And the contact page links "Contacts" to "/admin/contacts"
    And the contact page links "Email" to "/admin/mail?compose=1&to=ada@example.com"
    And the contact page offers the button "Star"
    And the contact page links "Edit" to "/admin/contacts/1/edit"
    And the contact page links "ada@example.com" to "mailto:ada@example.com"
    And the contact card reads "home"
    And the contact page links "+44 20 7946 0000" to "tel:+442079460000"
    And the contact card reads "12 St James's Square"
    And the contact card reads "Jabber"
    And the contact page links "@ada@ruby.social" to "https://ruby.social/@ada"
    And the contact page links "@ada.bsky.social" to "https://bsky.app/profile/did:plc:ada"
    And the contact card reads "@{ada}"
    And the contact card reads "copy"
    And the contact card reads "Countess"
    And the contact card reads "Dec 10, 1815"
    And the contact page gives the age for the birthday "1815-12-10"
    And the contact card reads "Jul 8"
    And the contact card reads "William King"
    And the contact card reads "Analytical"
    And the contact card reads "the first program"
    And the contact page links "ada.example" to "https://ada.example"
    And the contact page shows "javascript:alert(1)" without a link
    And the Google card reads "here only"
    And I do not see "Open in Google Contacts"
    And I see "No threads with ada@example.com yet."
    And the page has no axe breaches in light or dark

  Scenario: The contact page leaves out the sections with nothing in them
    Given a contact "Grace"
    When I open the contact "Grace"
    Then the contact page has no sections

  Scenario: The contact page lists the last six mail threads with the contact
    Given a contact "Ada Lovelace" with:
      """
      {"emails": [{"value": "ada@example.com"}]}
      """
    And mail threads with contacts:
      | subject  | from              | minutes |
      | Thread 0 | ADA@example.com   | 0       |
      | Thread 1 | ada@example.com   | 1       |
      | Thread 2 | ADA@example.com   | 2       |
      | Thread 3 | ada@example.com   | 3       |
      | Thread 4 | ADA@example.com   | 4       |
      | Thread 5 | ada@example.com   | 5       |
      | Thread 6 | ADA@example.com   | 6       |
      | Other    | grace@example.com | 0       |
    When I open the contact "Ada Lovelace"
    Then the contact page lists the threads "Thread 0, Thread 1, Thread 2, Thread 3, Thread 4, Thread 5"
    And the contact thread "Thread 0" opens the mail thread
    And the contact thread "Thread 0" is marked unread

  Scenario: The contact page stars and unstars the contact
    Given a contact "Ada Lovelace"
    When I open the contact "Ada Lovelace"
    And I click the contact button "Star"
    Then I see "Contact starred"
    And the contact "Ada Lovelace" is starred
    When I click the contact button "Starred"
    Then I see "Star taken off"
    And the contact "Ada Lovelace" is not starred

  Scenario: The contact page shows what Google holds and links to it
    Given the Google account "aaron@example.com" is connected with "contacts"
    And a contact "Ada Lovelace" with:
      """
      {"file_as": "Lovelace, Ada"}
      """
    And the contact "Ada Lovelace" is linked to Google as "c5502913380" under "aaron@example.com"
    When I open the contact "Ada Lovelace"
    Then the Google card reads "in sync"
    And the Google card reads "aaron@example.com"
    And the Google card reads "people/c5502913380"
    And the Google card reads "Lovelace, Ada"
    And the contact page links "Open in Google Contacts" to "https://contacts.google.com/person/c5502913380"

  Scenario: The contact page and its editor answer 404 for a contact who is not there
    Then the contacts address "/admin/contacts/999999" answers 404
    And the contacts address "/admin/contacts/999999/edit" answers 404
