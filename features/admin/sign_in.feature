Feature: Admin sign-in
  The owner signs in through GitHub, and the admin keeps everyone else out.

  Background:
    Given "owner@example.com" is an owner

  Scenario: The owner reaches the admin signed in
    Given I am signed in to the admin
    When I visit the admin
    Then I see the admin signed in

  Scenario: A visitor who has not signed in is sent to sign in
    When I visit the admin
    Then I am sent to sign in

  Scenario: The sign-in page offers GitHub and Google
    When I visit "/admin/sign-in"
    Then I see "Sign in with an account whose verified email is on the owner list."
    And the page has a "Sign in with GitHub" button
    And the page has a "Sign in with Google" button
    And the page has no axe breaches in light or dark
    When I send GET "/admin/sign-in"
    Then the answer has the header "Content-Security-Policy" holding "form-action 'self' https:"

  Scenario: The redirect to sign in tells search engines to stay away
    When I send GET "/admin/posts?page=2"
    Then the answer sends me to "/admin/sign-in"
    And the answer has the header "X-Robots-Tag" set to "noindex, nofollow"

  Scenario: Starting a GitHub sign-in sends me to GitHub with a PKCE challenge
    When I start a GitHub sign-in
    Then the sign-in went to "STUB/github/login/oauth/authorize"
    And the sign-in asked for:
      | client_id     | stub-client-id                       |
      | response_type | code                                 |
      | scope         | user:email                           |
      | redirect_uri  | SITE/admin/auth/github/callback      |
      | allow_signup  | false                                |
    And the sign-in sent a state of at least 32 characters
    And the sign-in sent an S256 code challenge

  Scenario: Starting a sign-in without a CSRF token is refused
    When I post to "/admin/sign-in/github" without a CSRF token
    Then the answer is 403

  Scenario: Signing in opens the admin page first asked for
    When I sign in with GitHub from "/admin?tab=today"
    Then the answer sends me to "/admin?tab=today"

  Scenario: Signing in from the sign-in page opens the admin
    When I sign in with GitHub from "/admin/sign-in"
    Then the answer sends me to "/admin"
    And I am still signed in

  Scenario: Signing in after a signed-out tab asked for the event stream opens the admin
    When I send GET "/admin/events"
    And I sign in with GitHub from "/admin/sign-in"
    Then the answer sends me to "/admin"

  Scenario: The signed-in admin renders and tells search engines to stay away
    When I sign in with GitHub
    And I send GET "/admin"
    Then the answer is 200
    And the answer has the header "X-Robots-Tag" set to "noindex, nofollow"
    And the answer shows "<meta name=\"robots\" content=\"noindex, nofollow\">"
    And the answer carries a CSRF token of 64 hex digits in the sign-out form

  Scenario: A missing admin page is the admin's not found page
    When I sign in with GitHub
    And I send GET "/admin/nowhere"
    Then the answer is 404
    And the answer shows "<title>Page not found | Admin | Aaron Allen</title>"

  Scenario: The session cookie lasts 30 days
    When I sign in with GitHub
    Then my session cookie expires in 30 days

  Scenario: GitHub gets the verifier behind the challenge
    When I start a GitHub sign-in
    And GitHub calls back to the last sign-in
    Then GitHub got the verifier behind sign-in 1's challenge

  Scenario: A code swapped in from another sign-in carries that sign-in's verifier and fails
    Given GitHub sign-in answers POST "/login/oauth/access_token" with status 400
    When I start 2 GitHub sign-ins
    And GitHub calls back to sign-in 2
    Then the answer is 502
    And GitHub did not get the verifier behind sign-in 1's challenge
    And GitHub got the verifier behind sign-in 2's challenge
    And I am signed out

  Scenario: An owner email in another case signs in
    Given GitHub says the account's email is "OWNER@EXAMPLE.COM"
    When I sign in with GitHub
    Then the answer sends me to "/admin"

  Scenario: Another GitHub account is turned away
    Given GitHub says the account's email is "stranger@example.com"
    When I sign in with GitHub
    Then the answer is 403
    And the answer shows "This GitHub account can"
    And I hold no live session cookie
    And I am signed out

  Scenario: An account whose owner email is not its primary is turned away
    Given GitHub answers GET "/user/emails" with:
      """
      [{ "email": "stranger@example.com", "primary": true, "verified": true },
        { "email": "owner@example.com", "primary": false, "verified": true }]
      """
    When I sign in with GitHub
    Then the answer is 403

  Scenario: An account whose primary email is not verified is turned away
    Given GitHub answers GET "/user/emails" with:
      """
      [{ "email": "owner@example.com", "primary": true, "verified": false }]
      """
    When I sign in with GitHub
    Then the answer is 403
    And I am signed out

  Scenario: An account with no emails is turned away
    Given GitHub answers GET "/user/emails" with:
      """
      []
      """
    When I sign in with GitHub
    Then the answer is 403

  Scenario: A second owner signs in
    Given "second@example.com" is an owner
    And GitHub says the account's email is "second@example.com"
    When I sign in with GitHub
    Then the answer sends me to "/admin"

  Scenario: With no owners nobody signs in
    Given there are no owners
    When I sign in with GitHub
    Then the answer is 403

  Scenario: Removing every owner ends a signed-in session
    When I sign in with GitHub
    And there are no owners
    Then I am signed out

  Scenario: A denied callback fails without asking GitHub for a token
    When I start a GitHub sign-in
    And GitHub calls back to the last sign-in denied
    Then the answer is 401
    And the answer shows "GitHub sign-in did not finish"
    And I am signed out
    And GitHub was asked for 0 tokens

  Scenario: A callback carrying no code fails without asking GitHub for a token
    When I start a GitHub sign-in
    And GitHub calls back to the last sign-in with no code
    Then the answer is 401
    And the answer shows "GitHub sign-in did not finish"
    And GitHub was asked for 0 tokens

  Scenario: A callback with a forged state fails and leaves the real sign-in waiting
    When I start a GitHub sign-in
    And GitHub calls back with the state "forged"
    Then the answer is 401
    And GitHub was asked for 0 tokens
    When GitHub calls back to the last sign-in
    Then the answer sends me to "/admin"

  Scenario: A callback without a started sign-in fails
    When GitHub calls back with the state "forged"
    Then the answer is 401

  Scenario: A replayed callback sends me to the admin without a second token
    When I start a GitHub sign-in
    And GitHub calls back to the last sign-in
    And GitHub calls back to the last sign-in
    Then the answer sends me to "/admin"
    And GitHub was asked for 1 token
    And I am still signed in

  Scenario: Either of two tabs signs in
    When I start 2 GitHub sign-ins
    And GitHub calls back to sign-in 1
    Then I am still signed in
    When GitHub calls back to sign-in 2
    Then the answer sends me to "/admin"
    And I am still signed in

  Scenario: The second of two tabs signs in on its own
    When I start 2 GitHub sign-ins
    And GitHub calls back to sign-in 2
    Then I am still signed in

  Scenario: A sixth sign-in drops the first of the five waiting
    When I start 6 GitHub sign-ins
    And GitHub calls back to sign-in 1
    Then the answer is 401
    When GitHub calls back to sign-in 6
    Then I am still signed in

  Scenario: A stray callback while signed in sends me to the admin and keeps me in
    When I sign in with GitHub
    And GitHub calls back with the state "forged"
    Then the answer sends me to "/admin"
    And GitHub was asked for 1 token
    And I am still signed in
    When I send GET "/admin"
    Then the answer is 200
    When GitHub calls back with no state
    Then I am still signed in
    When GitHub calls back with the state ""
    Then I am still signed in

  Scenario: A callback for another GitHub account while signed in ends the session
    When I sign in with GitHub
    And GitHub says the account's email is "stranger@example.com"
    And I sign in with GitHub from "/admin/sign-in"
    Then the answer is 403
    And I am signed out

  Scenario Outline: A sign-in GitHub cannot confirm fails
    Given <reply>
    When I sign in with GitHub
    Then the answer is 502
    And the answer shows "<says>"
    And I am signed out

    Examples:
      | reply                                                                                                       | says                                 |
      | GitHub sign-in answers POST "/login/oauth/access_token" with '{"error":"bad_verification_code"}'             | GitHub could not confirm who you are |
      | GitHub sign-in answers POST "/login/oauth/access_token" as JSON with "<html>Our proxy is down</html>"         | GitHub could not confirm who you are |
      | GitHub sign-in answers POST "/login/oauth/access_token" as XML with '{"access_token":"gho_token"}'            | Sign-in failed                       |
      | GitHub answers GET "/user/emails" with status 503                                                           | Sign-in failed                       |
      | GitHub answers GET "/user/emails" as HTML with "<html>Our proxy is down</html>"                               | GitHub could not confirm who you are |
      | GitHub answers GET "/user/emails" as JSON with "<html>Our proxy is down</html>"                               | Sign-in failed                       |

  @timeout:60_000
  Scenario: A sign-in fails when GitHub never answers
    Given GitHub sign-in never answers POST "/login/oauth/access_token"
    When I sign in with GitHub
    Then the answer is 502

  Scenario: Signing in sets a device cookie for the new device
    When I sign in with GitHub
    Then my device cookie names the only device, reads only under "/admin" and hides from scripts
    And my device cookie expires in 400 days

  Scenario: Signing in again keeps the device the browser holds
    When I sign in with GitHub
    And I note my device cookie
    And I sign out
    Then my device cookie is the one I noted
    When I sign in with GitHub
    Then my device cookie is the one I noted
    And there is 1 device

  Scenario Outline: A device cookie that names no device is swapped for a fresh one
    Given my browser holds the device cookie "<held>"
    When I sign in with GitHub
    Then my device cookie is not "<held>"
    And my device cookie names the only device, reads only under "/admin" and hides from scripts

    Examples:
      | held                                 |
      | 6f1c0c39-3f5b-4a59-9d3a-2a1d4c5e7f80 |
      | not-an-id                            |

  Scenario: A public page neither reads nor sets the device cookie
    When I sign in with GitHub
    And I send GET "/"
    Then the answer is 200
    And the answer sets no cookie
    And my device cookie names the only device, reads only under "/admin" and hides from scripts

  Scenario: Signing out sends me home and ends the session
    When I sign in with GitHub
    And I sign out
    Then the answer sends me to "/"
    And I hold no live session cookie
    And I am signed out

  Scenario: A session cookie copied before signing out no longer works
    When I sign in with GitHub
    And I keep a copy of my session cookie
    And I sign out
    And my browser puts the copy back
    Then I am signed out

  Scenario: Signing out on one device ends the session on the other
    When I sign in with GitHub
    And I sign in with GitHub on "my phone"
    And I sign out on "my phone"
    Then I am signed out

  Scenario: Signing out a device from the security tab ends only its session
    When I sign in with GitHub
    And I sign in with GitHub on "my phone"
    And "my phone" signs out my browser's device from the security tab
    Then I am signed out
    And "my phone" is still signed in

  Scenario: A device signed out from the security tab signs in again as the same device
    When I sign in with GitHub
    And I note my device cookie
    And I sign in with GitHub on "my phone"
    And "my phone" signs out my browser's device from the security tab
    And a second passes
    And I sign in with GitHub
    Then I am still signed in
    And my device cookie is the one I noted
    And there are 2 devices

  Scenario: Signing out my own device from the security tab ends my session
    When I sign in with GitHub
    And I sign out my own device from the security tab
    Then I am signed out

  Scenario: Signing out a device that is not there is not found
    When I sign in with GitHub
    And I post to "/admin/settings/security/devices/6f1c0c39-3f5b-4a59-9d3a-2a1d4c5e7f80/sign-out"
    Then the answer is 404

  Scenario: A session whose device is gone asks for sign-in again
    When I sign in with GitHub
    And every device is deleted
    Then I am signed out

  Scenario: Signing out without a CSRF token shows the form expired page in the admin layout
    When I sign in with GitHub
    And I sign out without a CSRF token
    Then the answer is 403
    And the answer shows "Form expired"
    And the answer shows "pill-nav"
    And the answer has the header "X-Robots-Tag" set to "noindex, nofollow"
    And I am still signed in

  Scenario: Signing out with a forged CSRF token is refused
    When I sign in with GitHub
    And I sign out with the CSRF token "forged"
    Then the answer is 403
    And I am still signed in

  Scenario: Signing out with another session's CSRF token is refused
    When I sign in with GitHub on "my phone"
    And I sign in with GitHub
    And I sign out with the CSRF token "my phone" holds
    Then the answer is 403

  Scenario: Signing out with the CSRF token in a header works
    When I sign in with GitHub
    And I sign out with the CSRF token in a header
    Then the answer sends me to "/"

  Scenario: A POST without a CSRF token while signed out shows no admin pills
    When I post to "/admin/sign-out" without a CSRF token
    Then the answer is 403
    And the answer does not say "pill-nav"

  Scenario: A Google callback whose state was minted for no sign-in fails
    When I send GET "/admin"
    And Google calls back with the state "forged"
    Then the answer is 401
