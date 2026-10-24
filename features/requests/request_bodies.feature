Feature: A request body
  The site reads at most 1 MB of a form or JSON body, refuses files where it takes none, and lets the routes
  that carry files in base64 or multipart read more once the sender proves who it is.

  Scenario: A form over 1 MB gets the 413 page and stores no message
    When I post a form field "message[body]" of 1048576 bytes to "/contact"
    Then it answers 413
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>413<"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_messages
      """

  Scenario: A form over 1 MB with no declared length gets the 413 page and stores no message
    When I post a form of "1 MB" to "/contact" with no declared length
    Then it answers 413
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>413<"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_messages
      """

  Scenario: A form under 1 MB with no declared length stores the message the action read
    When I send the contact form with no declared length:
      | reply_to | ada@example.com  |
      | subject  | A question       |
      | body     | About the beacon |
    Then the database answers "1" for:
      """
      SELECT count(*) FROM mail_messages
      """

  Scenario: A JSON body over 1 MB to the API answers 413 in JSON
    Given my requests send the header "Authorization" as "Bearer nope"
    And my requests send the header "Accept" as "application/json"
    When I post a JSON body of "1 MB" to "/api/v1/journal_entries"
    Then it answers 413
    And the JSON answer holds "status" as "413"

  Scenario: A JSON body under 1 MB to the API reaches the action
    Given my requests send the header "Authorization" as "Bearer nope"
    When I post a JSON body of "1 MB less a kilobyte" to "/api/v1/journal_entries"
    Then it answers 401

  Scenario: A JSON body over 1 MB to /mcp reaches the action, since it carries photos in base64
    Given my requests send the header "Authorization" as "Bearer nope"
    When I post a JSON body of "2 MB" to "/mcp"
    Then it answers 401

  Scenario Outline: A JSON body over 1 MB to <path> with a live token reaches the action
    Given my requests carry an API token
    When I post a JSON body of "2 MB" to "<path>"
    Then it answers 422

    Examples:
      | path                 |
      | /api/v1/photos       |
      | /api/v1/shares       |
      | /api/v1/share_groups |

  Scenario Outline: A JSON body over 1 MB to <path> with <kind> token answers 413 in JSON
    Given my requests carry <kind> API token
    And my requests send the header "Accept" as "application/json"
    When I post a JSON body of "2 MB" to "<path>"
    Then it answers 413
    And the JSON answer holds "status" as "413"

    Examples:
      | path                 | kind       |
      | /api/v1/photos       | an unknown |
      | /api/v1/photos       | a revoked  |
      | /api/v1/photos       | an expired |
      | /api/v1/shares       | an unknown |
      | /api/v1/shares       | a revoked  |
      | /api/v1/shares       | an expired |
      | /api/v1/share_groups | an unknown |
      | /api/v1/share_groups | a revoked  |
      | /api/v1/share_groups | an expired |

  Scenario Outline: A JSON body to <path> over the base64 upload limit answers 413 in JSON
    Given my requests carry an API token
    And my requests send the header "Accept" as "application/json"
    When I post a JSON body of "33.34 MB" to "<path>"
    Then it answers 413
    And the JSON answer holds "status" as "413"

    Examples:
      | path                 |
      | /mcp                 |
      | /api/v1/photos       |
      | /api/v1/shares       |
      | /api/v1/share_groups |

  Scenario Outline: A JSON body to <path> over 1 MB with no token answers 413 in JSON, and under 1 MB reaches the action
    Given my requests send the header "Accept" as "application/json"
    When I post a JSON body of "2 MB" to "<path>"
    Then it answers 413
    And the JSON answer holds "status" as "413"
    When I post a JSON body of "1 MB less a kilobyte" to "<path>"
    Then it answers 401

    Examples:
      | path                 |
      | /mcp                 |
      | /api/v1/photos       |
      | /api/v1/shares       |
      | /api/v1/share_groups |

  Scenario: A JSON body to the API reaches the router
    Given my requests send the header "Authorization" as "Bearer nope"
    When I post "/api/v1/token" with the "application/json" body:
      """
      {"note": "a"}
      """
    Then it answers 405

  Scenario: A multipart form to the contact page gets the 415 page and stores no message
    When I post the file "a.jpg" of type "image/jpeg" holding the bytes "70686f746f" as "photo" to "/contact"
    Then it answers 415
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>415<"
    And the database answers "0" for:
      """
      SELECT count(*) FROM mail_messages
      """

  Scenario Outline: A multipart POST to <path> answers 415
    Given my requests send the header "Authorization" as "Bearer nope"
    When I post the file "a.jpg" of type "image/jpeg" holding the bytes "70686f746f" as "photo" to "<path>"
    Then it answers 415

    Examples:
      | path           |
      | /api/v1/token  |
      | /mcp           |
      | /api/v1/photos |

  Scenario Outline: A <what> over <size> while signed in gets the 413 page
    Given I am signed in to the admin
    When I post a file of "<size> and a byte" as "attachments[]" to "<path>"
    Then it answers 413
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>413<"

    Examples:
      | what       | size  | path              |
      | mail draft | 2 MB  | /admin/mail/draft |
      | mail send  | 25 MB | /admin/mail/send  |

  Scenario: A photo upload over 1 MB while signed in reaches the action
    Given I am signed in to the admin
    When I post a file of "2 MB" as "photo" to "/admin/photos"
    Then it answers 403

  Scenario Outline: A <what> over <size> while signed out gets the 413 page
    When I post a file of "<size> and a byte" as "<field>" to "<path>"
    Then it answers 413
    And the body matches "<main[\s\S]*class=\"status\"[^>]*>413<"

    Examples:
      | what         | size  | field   | path          |
      | photo upload | 2 MB  | photo   | /admin/photos |
      | photo upload | 25 MB | photo   | /admin/photos |
      | share upload | 2 MB  | files[] | /admin/files  |
