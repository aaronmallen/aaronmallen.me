Feature: Adding, editing and deleting contacts
  The contact editor adds a contact, changes one and deletes one. It keeps
  what was typed and shows each refusal beside its field.

  Background:
    Given I am signed in to the admin

  Scenario: Adding a contact keeps every field, label and the star
    Given a contact "Grace Hopper" with:
      """
      {"labels": ["family"]}
      """
    When I visit "/admin/contacts/new"
    Then the contact form hides "Prefix" until asked
    And the contact form has no search box
    And the page has no axe breaches in light or dark
    When I click the contact button "Prefix, middle, suffix, phonetic, file as"
    And I fill in the contact field "Prefix" with "Dr."
    And I fill in the contact field "First" with "Ada"
    And I fill in the contact field "Middle" with "Augusta"
    And I fill in the contact field "Last" with "King"
    And I fill in the contact field "Suffix" with "FRS"
    And I fill in the contact field "Company" with "Engines"
    And I fill in the contact field "Nickname" with "Countess"
    And I fill in the contact field "Notes" with "the first program"
    And I add the contact row "Emails" as "ada@example.com"
    And I add the contact row "Emails" as ""
    And I add the contact row "Phones" as "+44 20 7946 0000"
    And I add the contact address in "London"
    And I add the custom contact field "Engine" as "Analytical"
    And I pick the contact label "#family"
    And I add the new contact label "Ruby Friends"
    And I star the contact in the form
    And I submit the contact form with "Add contact"
    Then I see "Contact added"
    And the browser is on the page of the contact "Dr. Ada Augusta King, FRS"
    And the contact "Dr. Ada Augusta King, FRS" holds:
      """
      {"company": "Engines", "nickname": "Countess", "notes": "the first program",
        "emails": [{"value": "ada@example.com", "type": "home"}],
        "phones": [{"value": "+44 20 7946 0000", "type": "mobile"}],
        "addresses": [{"city": "London", "type": "home"}],
        "custom_fields": [{"key": "Engine", "value": "Analytical"}],
        "labels": ["family", "ruby-friends"], "starred": true}
      """

  Scenario: Adding a contact refuses bad fields beside each one and keeps what I typed
    Given a contact "Grace Hopper" with:
      """
      {"key": "grace"}
      """
    When I visit "/admin/contacts/new"
    And I fill in the contact field "Nickname" with "Countess"
    And I submit the contact form with "Add contact"
    Then the contact editor answers with status 422
    And I see "Give them a name or a company."
    And the contact field "Nickname" holds "Countess"
    When I fill in the contact field "First" with "Ada"
    And I fill in the contact field "Mastodon" with "@ada@ruby.social"
    And I submit the contact form with "Add contact"
    Then I see "Someone you can mention needs a key."
    And the contact field "First" holds "Ada"
    When I fill in the contact field "Mention key" with "Ada L"
    And I submit the contact form with "Add contact"
    Then I see "A key is lowercase words joined by hyphens."
    When I fill in the contact field "Mention key" with "grace"
    And I submit the contact form with "Add contact"
    Then I see "Someone else already holds that key."
    When I fill in the contact field "Mention key" with "ada"
    And I fill in the contact field "Mastodon" with "ada"
    And I submit the contact form with "Add contact"
    Then I see "A Mastodon handle looks like @ada@ruby.social."
    When I fill in the contact field "Mastodon" with ""
    And I fill in the contact field "Bluesky" with "ada"
    And I submit the contact form with "Add contact"
    Then I see "A Bluesky handle looks like ada.bsky.social."
    And the contact field "First" holds "Ada"
    And the contacts are "Grace Hopper"

  Scenario: Adding a contact refuses an email that is not an address and keeps what I typed
    When I post the contact form with:
      """
      {"given_name": "Ada", "emails": [{"value": "ada at"}]}
      """
    Then the contact editor answers with status 422
    And the composer answer holds "One of those doesn’t look like an email address."
    And the composer answer holds "value=\"Ada\""
    And there are no contacts

  Scenario: Adding a contact with a Bluesky handle stores the DID it resolves to
    Given Bluesky's app view answers GET "/xrpc/com.atproto.identity.resolveHandle" with:
      """
      {"did": "did:plc:ada"}
      """
    When I visit "/admin/contacts/new"
    And I fill in the contact field "First" with "Ada"
    And I fill in the contact field "Mention key" with "ada"
    And I fill in the contact field "Bluesky" with "ada.bsky.social"
    And I submit the contact form with "Add contact"
    Then the contact "Ada" holds:
      """
      {"bluesky_handle": "ada.bsky.social", "bluesky_did": "did:plc:ada"}
      """

  Scenario: Adding a contact takes a company with no name
    When I visit "/admin/contacts/new"
    And I fill in the contact field "Company" with "Analytical Engines"
    And I submit the contact form with "Add contact"
    Then the contact header reads "Analytical Engines"
    And the contact "Analytical Engines" holds:
      """
      {"name": null, "company": "Analytical Engines"}
      """

  Scenario: A new contact fills from a name and an email and keeps the email on a refusal
    When I visit "/admin/contacts/new?name=Ada%20Lovelace&email=ada@example.com"
    Then the contact field "First" holds "Ada"
    And the contact field "Last" holds "Lovelace"
    And the contact field "Emails" holds "ada@example.com"
    When I fill in the contact field "First" with ""
    And I fill in the contact field "Last" with ""
    And I submit the contact form with "Add contact"
    Then I see "Give them a name or a company."
    And the contact field "Emails" holds "ada@example.com"

  Scenario: Editing a contact fills the form and saves every field it shows
    Given a contact "Ada Lovelace" with:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social", "labels": ["family"],
        "phones": [{"value": "+44 20 7946 0000", "type": "mobile"}]}
      """
    And a contact "Grace Hopper" with:
      """
      {"labels": ["navy"]}
      """
    When I edit the contact "Ada Lovelace"
    Then the contact field "First" holds "Ada"
    And the contact field "Last" holds "Lovelace"
    And the contact field "Phones" holds "+44 20 7946 0000"
    And the contact field "Phones type" holds "mobile"
    And the contact labels offered are "#family, #navy"
    And the contact label "#family" is picked
    And the contact label "#navy" is not picked
    And the contact form has no search box
    And the page has no axe breaches in light or dark
    When I fill in the contact field "Last" with "King"
    And I fill in the contact field "Company" with "IBM"
    And I remove the contact row "Remove phone"
    And I pick the contact label "#family"
    And I submit the contact form with "Save"
    Then I see "Contact saved"
    And the browser is on the page of the contact "Ada King"
    And the contact "Ada King" holds:
      """
      {"company": "IBM", "phones": [], "labels": [], "starred": false}
      """

  Scenario: Editing a contact adds a row, shows the extra name fields and adds a label
    Given a contact "Ada Lovelace" with:
      """
      {"key": "ada", "emails": [{"value": "ada@example.com"}]}
      """
    When I edit the contact "Ada Lovelace"
    And I add the contact row "Phones" as "+1 555 0100"
    And I remove the contact row "Remove email"
    And I click the contact button "Prefix, middle, suffix, phonetic, file as"
    And I fill in the contact field "Prefix" with "Countess"
    And I add the new contact label "Ruby Friends"
    And I submit the contact form with "Save"
    Then the contact header reads "Countess Ada Lovelace"
    And the contact header reads "#ruby-friends"
    And the contact page links "+1 555 0100" to "tel:+15550100"
    And I do not see "ada@example.com"

  Scenario: Editing a contact keeps the edit and shows the error on a refusal
    Given a contact "Ada Lovelace" with:
      """
      {"key": "ada", "mastodon_handle": "@ada@ruby.social"}
      """
    When I edit the contact "Ada Lovelace"
    And I fill in the contact field "Mention key" with ""
    And I fill in the contact field "Nickname" with "Countess"
    And I submit the contact form with "Save"
    Then I see "Someone you can mention needs a key."
    And the contact field "Nickname" holds "Countess"
    And the contact "Ada Lovelace" holds:
      """
      {"key": "ada", "nickname": null}
      """

  Scenario: Editing a contact keeps its company when the edit clears its name
    Given a contact "Ada Lovelace" with:
      """
      {"company": "Analytical Engines"}
      """
    When I edit the contact "Ada Lovelace"
    And I fill in the contact field "First" with ""
    And I fill in the contact field "Last" with ""
    And I submit the contact form with "Save"
    Then I see "Contact saved"
    And the contact "Analytical Engines" holds:
      """
      {"name": null, "company": "Analytical Engines"}
      """

  Scenario: Deleting a contact asks first, then goes back to the list
    Given a contact "Ada Lovelace"
    When I edit the contact "Ada Lovelace"
    And I click the contact button "Delete"
    Then the contact delete asks "Delete Ada Lovelace here and in Google?"
    When I decline the contact delete
    Then the contacts are "Ada Lovelace"
    When I click the contact button "Delete"
    And I confirm the contact delete
    Then I see "Contact deleted"
    And the browser is on the contacts list
    And there are no contacts

  Scenario: The social composer adds a person and answers with the mention option
    When I add a person through the social composer with:
      """
      {"name": "Ada Lovelace", "key": "ada", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the contact editor answers with status 201
    And the composer answer offers "Ada Lovelace" to mention as "ada" on "mastodon"
    And the composer answer lists the handles:
      """
      {"mastodon": {"ada": "@ada@ruby.social"}, "bluesky": {"ada": "Ada Lovelace"},
        "linkedin": {"ada": "Ada Lovelace"}}
      """
    And the composer answer has no layout and no toast
    And the contacts are "Ada Lovelace"

  Scenario: The social composer answers a refusal with its short form and the error
    When I add a person through the social composer with:
      """
      {"name": "Ada", "mastodon_handle": "@ada@ruby.social"}
      """
    Then the contact editor answers with status 422
    And the composer answer holds "data-person-form=\"new\""
    And the composer answer holds "Someone you can mention needs a key."
    And there are no contacts

  Scenario: The social composer's short form fills the key from the name
    When I visit "/admin/contacts/new?reply=mention"
    Then I see "Add person"
    When I fill in the contact field "Name" with "Ada Lovelace"
    Then the composer form fills the key "ada-lovelace"
    And the page has no axe breaches in light or dark
