Feature: Admin sign-in
  The owner signs in through GitHub, and the admin keeps everyone else out.

  Scenario: The owner reaches the admin signed in
    Given I am signed in to the admin
    When I visit the admin
    Then I see the admin signed in

  Scenario: A visitor who has not signed in is sent to sign in
    When I visit the admin
    Then I am sent to sign in
