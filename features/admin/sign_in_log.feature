Feature: Admin sign-in log
  Each sign-in, and each failed one, leaves a row with its outcome, provider, address and device.

  Background:
    Given "owner@example.com" is an owner
    And "my laptop" sends the user agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36"

  Scenario: Signing in records the sign-in with its address, device and time
    When I sign in with GitHub on "my laptop"
    Then the database answers "signed_in, github, 127.0.0.1, Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36, Chrome, macOS, true" for:
      """
      SELECT outcome, provider, address, user_agent, browser, os, created_at > now() - interval '1 minute'
      FROM sign_ins
      """

  Scenario: Signing in keeps no more than 1024 characters of the user agent
    Given "my tablet" sends a user agent of 2000 characters
    When I sign in with GitHub on "my tablet"
    Then the database answers "1024" for:
      """
      SELECT length(user_agent) FROM sign_ins
      """

  Scenario Outline: Signing in reads <browser> on <os> from the user agent
    Given "my tablet" sends the user agent "<user agent>"
    When I sign in with GitHub on "my tablet"
    Then the database answers "<browser>, <os>" for:
      """
      SELECT coalesce(browser, 'none') AS browser, coalesce(os, 'none') AS os FROM sign_ins
      """

    Examples:
      | user agent                                                                                       | browser | os       |
      | Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Version/18.0 Mobile Safari/604.1          | Safari  | iOS      |
      | Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0                 | Firefox | Windows  |
      | Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0           | Edge    | Windows  |
      | Mozilla/5.0 (Linux; Android 15; Pixel 9) Chrome/141.0.0.0 Mobile Safari/537.36                   | Chrome  | Android  |
      | Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) Chrome/141.0.0.0 Safari/537.36                          | Chrome  | ChromeOS |
      | Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0                           | Firefox | Linux    |
      | curl/8.7.1                                                                                       | none    | none     |

  Scenario: Three sign-ins from one browser name one device
    When I sign in with GitHub on "my laptop"
    And I sign in with GitHub on "my laptop"
    And I sign in with GitHub on "my laptop"
    Then the database answers "Chrome, macOS, 3, true" for:
      """
      SELECT d.browser, d.os, count(s.id), d.last_signed_in_at >= max(s.created_at) - interval '1 second'
      FROM devices d JOIN sign_ins s ON s.device_id = d.id GROUP BY d.id
      """

  Scenario: Sign-ins from two browsers name two devices
    Given "my phone" sends the user agent "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0"
    When I sign in with GitHub on "my laptop"
    And I sign in with GitHub on "my phone"
    Then the database answers "Chrome Firefox" for:
      """
      SELECT string_agg(browser, ' ' ORDER BY browser) FROM devices
      """

  Scenario: A denied callback from a known device names the device
    When I sign in with GitHub on "my laptop"
    And I start a GitHub sign-in on "my laptop"
    And GitHub calls back to "my laptop"'s last sign-in denied
    Then the database answers "signed_in denied, true" for:
      """
      SELECT string_agg(outcome::text, ' ' ORDER BY id) AS outcomes, bool_and(device_id = (SELECT id FROM devices)) AS named FROM sign_ins
      """

  Scenario: A denied callback from a browser with no device records no device
    When I start a GitHub sign-in on "my laptop"
    And GitHub calls back to "my laptop"'s last sign-in denied
    Then the database answers "denied, true" for:
      """
      SELECT outcome, device_id IS NULL AS deviceless FROM sign_ins
      """
    And there are 0 devices

  Scenario: A stray callback from a device that just signed in writes no row
    When I sign in with GitHub on "my laptop"
    And GitHub calls back to "my laptop" with the state "taken"
    Then the answer sends me to "/admin"
    And the database answers "signed_in" for:
      """
      SELECT string_agg(outcome::text, ' ' ORDER BY id) FROM sign_ins
      """

  Scenario: A stray callback from a device that signed in a minute ago or more is denied
    When I sign in with GitHub on "my laptop"
    And the database runs "UPDATE devices SET last_signed_in_at = now() - interval '61 seconds'"
    And GitHub calls back to "my laptop" with the state "taken"
    Then the answer is 401
    And the database answers "signed_in denied" for:
      """
      SELECT string_agg(outcome::text, ' ' ORDER BY id) FROM sign_ins
      """

  Scenario: A stray callback from a browser with no device cookie is denied
    When I sign in with GitHub on "my laptop"
    And GitHub calls back to "my phone" with the state "taken"
    Then the answer is 401
    And the database answers "signed_in denied" for:
      """
      SELECT string_agg(outcome::text, ' ' ORDER BY id) FROM sign_ins
      """

  Scenario: A stray callback with a device cookie that is no ID is denied
    Given my browser holds the device cookie "not-an-id"
    When GitHub calls back with the state "taken"
    Then the database answers "denied" for:
      """
      SELECT outcome FROM sign_ins
      """

  Scenario: A denied callback whose state matched is recorded even from a device that just signed in
    When I sign in with GitHub on "my laptop"
    And I start a GitHub sign-in on "my laptop"
    And GitHub calls back to "my laptop"'s last sign-in denied
    Then the database answers "signed_in denied" for:
      """
      SELECT string_agg(outcome::text, ' ' ORDER BY id) FROM sign_ins
      """

  Scenario: Another GitHub account records a wrong account
    Given GitHub says the account's email is "stranger@example.com"
    When I sign in with GitHub
    Then the database answers "wrong_account" for:
      """
      SELECT outcome FROM sign_ins
      """

  Scenario: A denied callback records a denied sign-in
    When I start a GitHub sign-in
    And GitHub calls back to the last sign-in denied
    Then the database answers "denied" for:
      """
      SELECT outcome FROM sign_ins
      """

  Scenario: A callback GitHub fails records a provider failure with its address
    Given GitHub sign-in answers POST "/login/oauth/access_token" with '{"error":"bad_verification_code"}'
    When I sign in with GitHub
    Then the database answers "provider_failed, github, 127.0.0.1" for:
      """
      SELECT outcome, provider, address FROM sign_ins
      """

  Scenario: Failed callbacks past the limit stop being recorded
    When GitHub calls back with the state "never-started" 11 times
    Then the answer is 401
    And the database answers "10" for:
      """
      SELECT count(*) FROM sign_ins WHERE outcome = 'denied'
      """

  Scenario: Failed callbacks older than the window no longer count
    When GitHub calls back with the state "never-started" 10 times
    And the database runs "UPDATE sign_ins SET created_at = now() - interval '2 hours'"
    And GitHub calls back with the state "never-started" 1 time
    Then the table sign_ins holds 11 rows

  Scenario: A sign-in that goes through is recorded past the limit
    When GitHub calls back with the state "never-started" 11 times
    And I sign in with GitHub
    Then the database answers "10, 1" for:
      """
      SELECT count(*) FILTER (WHERE outcome = 'denied') AS denied, count(*) FILTER (WHERE outcome = 'signed_in') AS went FROM sign_ins
      """

  Scenario: A public visit records no sign-in
    When I send GET "/"
    Then the answer is 200
    And the table sign_ins holds 0 rows
