Feature: Google connection
  I connect any number of Google accounts, each with the scopes I tick. Mail,
  calendar, contacts and Health jobs read Google through them.

  Background:
    Given I am signed in to the admin

  Scenario: The dialog ticks every scope and locks the address on
    When I visit "/admin/settings/services"
    Then the service picker offers "Google"
    And the Google scope "Read sleep" is ticked and free
    And the Google scope "See your address" is ticked and locked on

  Scenario: Connecting sends me to Google for every scope, offline, with a PKCE challenge
    Given Google shows its sign-in page
    When I connect Google
    Then the authorize request went to "/google/accounts/o/oauth2/v2/auth"
    And the authorize request asked with "client_id" as "stub-google-id"
    And the authorize request asked with "access_type" as "offline"
    And the authorize request asked with "prompt" as "select_account consent"
    And the authorize request scope holds "openid"
    And the authorize request scope holds "https://www.googleapis.com/auth/userinfo.email"
    And the authorize request scope holds "https://mail.google.com/"
    And the authorize request scope holds "https://www.googleapis.com/auth/calendar"
    And the authorize request scope holds "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
    And the authorize request sent a PKCE challenge and comes back to "/admin/auth/google/callback"

  Scenario: Unticking Health leaves it out of the ask
    Given Google shows its sign-in page
    When I connect Google without "Read workouts, Read sleep, Read heart rate"
    Then the authorize request scope holds "openid"
    And the authorize request scope holds "https://mail.google.com/"
    And the authorize request scope leaves out "googlehealth"

  Scenario: The ask always holds the address
    Given Google shows its sign-in page
    When I connect Google asking only for "Read, send, label and delete mail"
    Then the authorize request asked for the scopes "openid https://www.googleapis.com/auth/userinfo.email https://mail.google.com/"

  Scenario: The ask leaves out a scope the definition does not list
    Given Google shows its sign-in page
    When I connect Google with the extra scope "https://www.googleapis.com/auth/drive"
    Then the authorize request scope leaves out "https://www.googleapis.com/auth/drive"

  Scenario: Google grants access and the site saves the account and backfills Health from today
    Given Google shows its sign-in page
    And Google grants "aaron@example.com" the scopes "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
    And Google has no Health data for the connection
    When I connect Google
    And I approve the connection
    Then the connection toast says "Google connected as aaron@example.com"
    And the Google connection "aaron@example.com" has the account "aaron@example.com" and the scopes "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
    And the Google connection "aaron@example.com" holds the credentials '{"access_token": "ya29.aaron@example.com", "refresh_token": "1//aaron@example.com"}'
    And the stored Google credentials do not hold "1//aaron@example.com"
    And Google Health received GET "/users/me/dataTypes/sleep/dataPoints"
    And the service row "Google" shows "connected"
    And the service line "Read sleep" shows "granted"
    And the service picker offers "Google"
    And the page has no axe breaches in light or dark

  Scenario: A second and third account each keep their own scopes and skip the Health backfill
    Given the Google account "aaron@example.com" is connected with "googlehealth.sleep.readonly"
    And Google shows its sign-in page
    And Google grants "work@example.com" the scopes "openid https://mail.google.com/"
    When I connect Google
    And I approve the connection
    Then the site holds the Google connections "aaron@example.com, work@example.com"
    Given Google grants "other@example.com" the scopes "https://www.googleapis.com/auth/calendar.events"
    When I connect Google
    And I approve the connection
    Then the site holds the Google connections "aaron@example.com, work@example.com, other@example.com"
    And the Google connection "work@example.com" has the scopes "openid https://mail.google.com/"
    And the Google connection "other@example.com" has the scopes "https://www.googleapis.com/auth/calendar.events"
    When the queued connection jobs finish
    Then Google Health received no GET "/users/me/dataTypes/sleep/dataPoints"
    When I open the connection "work@example.com"
    Then the service line "Read, send, label and delete mail" shows "granted"
    And the service line "Read sleep" shows "off"

  Scenario: An account that left a scope off offers Change access with its scopes ticked
    Given the Google account "me" is connected with "googlehealth.sleep.readonly"
    When I open the connection "me"
    Then the service line "Read, send, label and delete mail" shows "off"
    And the service panel offers no orange pill on "Read, send, label and delete mail"
    And the service panel offers no "Grant"
    And the service panel offers "Change access"
    And the change access dialog for "me" ticks "Read sleep" and not "Read, send, label and delete mail"

  Scenario: Change access adds the scope to the same account
    Given the Google account "aaron@example.com" is connected with "googlehealth.sleep.readonly"
    And Google shows its sign-in page
    And Google grants "aaron@example.com" the scopes "https://www.googleapis.com/auth/googlehealth.sleep.readonly https://mail.google.com/"
    And Google has no Health data for the connection
    When I change Google access for "aaron@example.com" to add "Read, send, label and delete mail"
    And I approve the connection
    Then the Google connection "aaron@example.com" has the scopes "https://www.googleapis.com/auth/googlehealth.sleep.readonly https://mail.google.com/"
    And the Google connection "aaron@example.com" is still row 1
    And the site holds the Google connections "aaron@example.com"

  Scenario: Picking another account in Google's chooser adds it and leaves the first alone
    Given the Google account "aaron@example.com" is connected with "googlehealth.sleep.readonly"
    And Google shows its sign-in page
    And Google grants "work@example.com" the scopes "https://mail.google.com/"
    When I change Google access for "aaron@example.com" to add "Read, send, label and delete mail"
    And I approve the connection
    Then the site holds the Google connections "aaron@example.com, work@example.com"
    And the Google connection "aaron@example.com" has the scopes "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
    And the Google connection "aaron@example.com" holds the credentials '{"access_token": "ya29.aaron@example.com"}'
    And the Google connection "work@example.com" has the scopes "https://mail.google.com/"

  Scenario: Reconnecting a row held without an address gives it the address
    Given the Google account "me" is connected with "googlehealth.sleep.readonly"
    And Google shows its sign-in page
    And Google grants "aaron@example.com" the scopes "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
    And Google has no Health data for the connection
    When I change Google access for "me" to add "Read, send, label and delete mail"
    And I approve the connection
    Then the Google connection "aaron@example.com" is still row 1
    And the Google connection "aaron@example.com" holds the credentials '{"access_token": "ya29.aaron@example.com"}'

  Scenario: Declining on Google saves nothing
    Given Google shows its sign-in page
    When I connect Google
    And I decline the connection
    Then the connection toast says "Google didn't grant access"
    And the site holds no Google connection

  Scenario: A failed token exchange saves nothing
    Given Google shows its sign-in page
    And Google's token exchange refuses the code
    When I connect Google
    And I approve the connection
    Then the site holds no Google connection

  Scenario: A token answer that is not JSON saves nothing
    Given Google shows its sign-in page
    And Google's token exchange answers "<html>"
    When I connect Google
    And I approve the connection
    Then the connection toast says "Google didn't answer"
    And the site holds no Google connection

  Scenario: A user answer that is not JSON saves nothing
    Given Google shows its sign-in page
    And Google's token exchange answers '{"access_token": "ya29.new", "expires_in": 3599, "token_type": "Bearer"}'
    And Google OpenID answers GET "/userinfo" with:
      """
      <html>
      """
    When I connect Google
    And I approve the connection
    Then the connection toast says "Google didn't answer"
    And the site holds no Google connection

  Scenario: A user with no address saves nothing
    Given Google shows its sign-in page
    And Google's token exchange answers '{"access_token": "ya29.new", "expires_in": 3599, "token_type": "Bearer"}'
    And Google OpenID answers GET "/userinfo" with:
      """
      {"sub": "1"}
      """
    When I connect Google
    And I approve the connection
    Then the connection toast says "Google didn't answer"
    And the site holds no Google connection

  Scenario: The site refuses a state it never sent
    When I come back from Google with a state it never sent
    Then the site holds no Google connection

  Scenario: A job refreshes an expired token, reads with it and keeps the refresh token
    Given the Google account "me" is connected with "calendar"
    And the Google account "me" holds an expired token
    And Google refreshes the token as "ya29.fresh"
    When the Google calendar sync runs
    Then Google OAuth received POST "/token" holding "grant_type=refresh_token"
    And Google OAuth received POST "/token" holding "refresh_token=1%2F%2Fme"
    And the Google connection "me" holds the credentials '{"access_token": "ya29.fresh", "refresh_token": "1//me"}'
    And Google Calendar received GET "/users/me/calendarList"

  Scenario: A revoked refresh token marks the account for a reconnect and stops asking Google
    Given the Google account "me" is connected with "calendar"
    And the Google account "me" holds an expired token
    And Google's token exchange refuses the code
    When the Google calendar sync runs
    Then the Google connection "me" needs a reconnect
    When the Google calendar sync runs again
    Then Google OAuth received POST "/token" once
    When I open the connection "me"
    Then the service row "Google" shows "needs reconnect"
    And the service panel holds a reconnect for "me"
    And the service panel shows "Google stopped taking the site's token. Reconnect and its jobs resume."

  Scenario: Reconnecting a revoked account clears the mark and lets it read again
    Given the Google account "me" is connected with "googlehealth.sleep.readonly"
    And the Google account "me" needs a reconnect
    And Google shows its sign-in page
    And Google grants "aaron@example.com" the scopes "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
    When I reconnect the Google connection "me"
    And I approve the connection
    Then the site holds the Google connections "aaron@example.com"
    And the Google connection "aaron@example.com" needs no reconnect
    When I test the connection "aaron@example.com"
    Then the connection toast says "Google answered"

  Scenario: A test reports that the account answers
    Given the Google account "me" is connected with "googlehealth.sleep.readonly"
    And Google OpenID answers GET "/userinfo" with:
      """
      {"email": "aaron@example.com"}
      """
    When I test the connection "me"
    Then the connection toast says "Google answered"

  Scenario: The work account switch marks one account and turns back off
    Given the Google account "me" is connected with "googlehealth.sleep.readonly"
    And the Google account "work@example.com" is connected with "googlehealth.sleep.readonly"
    When I open the connection "me"
    Then the work account switch is off
    When I flip the work account switch on "me"
    Then the Google connection "me" is a work account
    And the Google connection "work@example.com" is not a work account
    And the work account switch is on
    When I flip the work account switch on "me"
    Then the Google connection "me" is not a work account

  Scenario: Disconnecting one account revokes it on Google and leaves the others
    Given the Google account "me" is connected with "googlehealth.sleep.readonly"
    And the Google account "work@example.com" is connected with "googlehealth.sleep.readonly"
    And Google OAuth answers POST "/revoke" with:
      """
      {}
      """
    When I disconnect the connection "me"
    Then Google OAuth received POST "/revoke" holding "token=1%2F%2Fme"
    And Google OAuth received POST "/revoke" once
    And the site holds the Google connections "work@example.com"
