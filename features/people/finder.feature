Feature: Finding people on Mastodon and Bluesky
  The contacts list has a panel that searches Mastodon or Bluesky for an
  account and opens a new contact filled from the one I pick.

  Background:
    Given I am signed in to the admin

  Scenario: The people finder sits beside the list and relabels its box for the network I pick
    Given the admin can search people on "Mastodon and Bluesky"
    When I visit "/admin/contacts"
    Then the people finder offers "Mastodon"
    And the people finder offers "Bluesky"
    And the people finder box reads "Search Mastodon"
    And the page has no axe breaches in light or dark
    When I pick the people search network "Bluesky"
    Then the people finder box reads "Search Bluesky"

  Scenario: The people finder offers only the networks with credentials
    Given the admin can search people on "Mastodon"
    When I visit "/admin/contacts"
    Then the people finder offers "Mastodon"
    And the people finder does not offer "Bluesky"

  Scenario: The contacts list leaves the people finder out when no network has credentials
    When I visit "/admin/contacts"
    Then the contacts page has no people finder

  Scenario: The people finder counts what it finds and opens a new contact from Add
    Given the admin can search people on "Mastodon and Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with:
      """
      {"actors": [{"displayName": "Ada Lovelace", "handle": "ada.bsky.social"}]}
      """
    When I visit "/admin/contacts"
    And I search people on "Bluesky" for "ada"
    Then the people finder shows "1 account found"
    And the people finder shows "@ada.bsky.social"
    When I add the found account "Ada Lovelace"
    Then the contact field "First" holds "Ada"
    And the contact field "Last" holds "Lovelace"
    And the contact field "Mention key" holds "ada"
    And the contact field "Bluesky" holds "ada.bsky.social"

  Scenario: The people finder searches on Enter and adds the contact it found
    Given the admin can search people on "Mastodon and Bluesky"
    And Mastodon answers GET "/203.0.113.5/api/v2/search" with:
      """
      {"accounts": [{"acct": "grace@hachyderm.io", "display_name": "Grace Hopper"}]}
      """
    When I visit "/admin/contacts"
    And I search people on "Mastodon" for "grace" with Enter
    Then the people finder shows "@grace@hachyderm.io"
    When I add the found account "Grace Hopper"
    And I submit the contact form with "Add contact"
    Then the contact header reads "Grace Hopper"
    And the contact "Grace Hopper" holds:
      """
      {"key": "grace", "mastodon_handle": "@grace@hachyderm.io"}
      """

  Scenario: The people finder shows the error when the network fails
    Given the admin can search people on "Mastodon and Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with status 502
    When I visit "/admin/contacts"
    And I search people on "Bluesky" for "ada"
    Then the people finder shows "Bluesky did not answer"

  Scenario: The people finder keeps its results when a change redraws the page
    Given the admin can search people on "Mastodon and Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with:
      """
      {"actors": []}
      """
    When I visit "/admin/contacts"
    And I search people on "Bluesky" for "nobody"
    Then the people finder shows "No accounts match."
    Given a contact "Grace Hopper"
    Then the contacts list names "Grace Hopper"
    And the people finder shows "No accounts match."

  Scenario: The account search answers with rows and no layout
    Given the admin can search people on "Mastodon and Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with:
      """
      {"actors": [{"avatar": "https://203.0.113.20/ada.jpg", "displayName": "Ada Lovelace", "handle": "ada.bsky.social"},
                  {"avatar": "http://203.0.113.20/ada2.jpg", "displayName": "", "handle": "ada2.bsky.social"}]}
      """
    When I fetch the contact search "/admin/contacts/search/bluesky?q=ada"
    Then the contact search answers with status 200
    And the contact search answer does not hold "<html"
    And the contact search answer holds "2 accounts found"
    And the contact search answer holds "src=\"https://203.0.113.20/ada.jpg\""
    And the contact search answer does not hold "http://203.0.113.20/ada2.jpg"
    And the contact search answer holds "@ada.bsky.social"
    And the contact search answer holds "<p class=\"person-result-name\">ada2.bsky.social</p>"
    And the contact search offers to add "/admin/contacts/new?name=Ada Lovelace&person[key]=ada&person[bluesky_handle]=ada.bsky.social"

  Scenario: The account search names Mastodon accounts as @user@instance
    Given the admin can search people on "Mastodon and Bluesky"
    And Mastodon answers GET "/203.0.113.5/api/v2/search" with:
      """
      {"accounts": [{"acct": "ada", "display_name": "Ada"}, {"acct": "grace@hachyderm.io", "display_name": "Grace Hopper"}]}
      """
    When I fetch the contact search "/admin/contacts/search/mastodon?q=ada"
    Then the contact search answer holds "@ada@203.0.113.5"
    And the contact search answer holds "@grace@hachyderm.io"

  Scenario: The account search asks no network for a query shorter than two characters
    Given the admin can search people on "Mastodon and Bluesky"
    When I fetch the contact search "/admin/contacts/search/bluesky?q=%20a%20"
    Then the contact search answers with status 200
    And Bluesky's app view received no GET "/xrpc/app.bsky.actor.searchActorsTypeahead"

  Scenario: The account search shows an error row when the network fails or rate limits
    Given the admin can search people on "Mastodon and Bluesky"
    And Bluesky's app view answers GET "/xrpc/app.bsky.actor.searchActorsTypeahead" with status 502
    And Mastodon answers GET "/203.0.113.5/api/v2/search" with status 429
    When I fetch the contact search "/admin/contacts/search/bluesky?q=ada"
    Then the contact search answers with status 502
    And the contact search answer holds "Bluesky did not answer"
    When I fetch the contact search "/admin/contacts/search/mastodon?q=grace"
    Then the contact search answers with status 429
    And the contact search answer holds "too many searches"

  Scenario: The account search answers 404 for a network it cannot search
    Given the admin can search people on "Mastodon"
    When I fetch the contact search "/admin/contacts/search/bluesky?q=ada"
    Then the contact search answers with status 404
    When I fetch the contact search "/admin/contacts/search/myspace?q=ada"
    Then the contact search answers with status 404

  Scenario: The contact form has no search boxes
    Given the admin can search people on "Mastodon and Bluesky"
    And a contact "Ada Lovelace"
    When I visit "/admin/contacts/new"
    Then the contact form has no search box
    When I edit the contact "Ada Lovelace"
    Then the contact form has no search box
