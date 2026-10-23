Feature: LinkedIn connection
  I connect LinkedIn profiles to post from the social queue. LinkedIn tokens
  lapse after sixty days, so the site warns me before then.

  Background:
    Given I am signed in to the admin

  Scenario: Connecting sends me to LinkedIn for my name and the right to post
    Given LinkedIn shows its sign-in page
    When I visit "/admin/settings/services"
    Then the service picker offers "LinkedIn"
    When I connect LinkedIn
    Then the authorize request went to "/linkedin/oauth/authorization"
    And the authorize request asked with "client_id" as "stub-linkedin-id"
    And the authorize request scope holds "openid"
    And the authorize request scope holds "profile"
    And the authorize request scope holds "w_member_social"
    And the authorize request comes back to "/admin/auth/linkedin/callback"

  Scenario: LinkedIn grants access and the site keys the profile on the member
    Given LinkedIn shows its sign-in page
    And LinkedIn grants the member "member-ada" named "Ada Lovelace"
    When I connect LinkedIn
    And I approve the connection
    Then the connection toast says "LinkedIn connected as Ada Lovelace"
    And the LinkedIn connection "Ada Lovelace" has the account "member-ada" and the scopes "email openid profile w_member_social"
    And the LinkedIn connection "Ada Lovelace" holds the credentials '{"access_token": "li-member-ada"}'
    And the LinkedIn connection "Ada Lovelace" lapses in about 60 days
    And LinkedIn OAuth received POST "/accessToken" holding "client_id=stub-linkedin-id"
    And LinkedIn OAuth received POST "/accessToken" holding "client_secret=stub-linkedin-secret"
    And LinkedIn OAuth received POST "/accessToken" holding "code=code"

  Scenario: Two profiles show on the services page, the composer and the post form
    Given a Mastodon connection as "@aaron@203.0.113.9" on "203.0.113.9" with the scopes "write:statuses"
    And LinkedIn shows its sign-in page
    And LinkedIn grants the member "member-ada" named "Ada Lovelace"
    When I connect LinkedIn
    And I approve the connection
    Given LinkedIn grants the member "member-grace" named "Grace Hopper"
    When I connect LinkedIn
    And I approve the connection
    Then the site holds the LinkedIn connections "Ada Lovelace, Grace Hopper"
    When I visit "/admin/settings/services"
    Then the services group "Social" lists "Bridgy, LinkedIn, LinkedIn, Mastodon"
    And the service rows show the accounts "Ada Lovelace, Grace Hopper"
    And the composer lists the LinkedIn accounts "Ada Lovelace, Grace Hopper" beside Mastodon
    And the LinkedIn post target is on on the post form

  Scenario: A profile close to lapsing is marked and offers a reconnect
    Given a LinkedIn connection to "Ada Lovelace" that lapses in 3 days
    When I open the connection "Ada Lovelace"
    Then the service row "Ada Lovelace" shows "lapses soon"
    And the service panel shows "LinkedIn stops taking the site's token on"
    And the service panel offers "Reconnect"

  Scenario: A profile is marked lapsed once its expiry passes
    Given a LinkedIn connection to "Ada Lovelace" that lapsed a minute ago
    When I open the connection "Ada Lovelace"
    Then the service row "Ada Lovelace" shows "lapsed"
    And the service panel shows "LinkedIn no longer takes the site's token"

  Scenario: A profile lapsing late on the last day of the window shows on both pages
    Given a LinkedIn connection to "Ada Lovelace" that lapses in 7 days
    And the LinkedIn connection to "Ada Lovelace" lapses at "23:59" on the 7th day from today
    When I visit "/admin/settings/services"
    Then the service row "Ada Lovelace" shows "lapses soon"
    And the today page shows a lapsing connection

  Scenario: A profile more than a week out stays connected
    Given a LinkedIn connection to "Ada Lovelace" that lapses in 8 days
    And the LinkedIn connection to "Ada Lovelace" lapses at "00:00" on the 8th day from today
    When I visit "/admin/settings/services"
    Then the service row "Ada Lovelace" shows "connected"

  Scenario: Reconnecting a held profile replaces its token and keeps its deliveries
    Given a LinkedIn connection to "Ada Lovelace" that lapses in 1 day
    And a sent LinkedIn post delivered through "Ada Lovelace"
    And LinkedIn shows its sign-in page
    And LinkedIn grants the member "member-ada" named "Ada Lovelace"
    When I reconnect the LinkedIn connection "Ada Lovelace"
    And I approve the connection
    Then the connection toast says "LinkedIn connected as Ada Lovelace"
    And the site holds the LinkedIn connections "Ada Lovelace"
    And the LinkedIn connection "Ada Lovelace" is still row 1
    And the LinkedIn connection "Ada Lovelace" holds the credentials '{"access_token": "li-member-ada"}'
    And the LinkedIn connection "Ada Lovelace" lapses in about 60 days
    And the service row "Ada Lovelace" shows "connected"
    And the today page shows no lapsing connection
    And the social post deliveries point at the LinkedIn connection "Ada Lovelace"

  Scenario: Declining on LinkedIn saves nothing
    Given LinkedIn shows its sign-in page
    When I connect LinkedIn
    And I decline the connection
    Then the connection toast says "LinkedIn didn't grant access"
    And the site holds no LinkedIn connection

  Scenario: A failed token exchange saves nothing
    Given LinkedIn shows its sign-in page
    And LinkedIn's token exchange fails
    When I connect LinkedIn
    And I approve the connection
    Then the connection toast says "LinkedIn didn't answer"
    And the site holds no LinkedIn connection

  Scenario: A member answer that is not JSON saves nothing
    Given LinkedIn shows its sign-in page
    And LinkedIn grants the member "member-ada" named "Ada Lovelace"
    And LinkedIn answers GET "/v2/userinfo" with:
      """
      <html>
      """
    When I connect LinkedIn
    And I approve the connection
    Then the site holds no LinkedIn connection

  Scenario: The site refuses a state it never sent
    When I come back from LinkedIn with a state it never sent
    Then the site holds no LinkedIn connection

  Scenario: Disconnecting a profile revokes its token and keeps its deliveries
    Given a LinkedIn connection to "Ada Lovelace" that lapses in 30 days
    And a sent LinkedIn post delivered through "Ada Lovelace"
    And LinkedIn OAuth answers POST "/revoke" with:
      """
      {}
      """
    When I disconnect the connection "Ada Lovelace"
    Then LinkedIn OAuth received POST "/revoke" holding "client_id=stub-linkedin-id"
    And LinkedIn OAuth received POST "/revoke" holding "client_secret=stub-linkedin-secret"
    And LinkedIn OAuth received POST "/revoke" holding "token=li-token"
    And LinkedIn OAuth received POST "/revoke" once
    And the site holds no LinkedIn connection
    And the LinkedIn delivery is kept with no connection
