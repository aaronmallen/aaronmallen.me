Feature: MCP tool descriptions
  Tools that share a rule describe it in the same words.

  Background:
    Given an MCP client connected with the scopes "read suggest write publish delete mail"
    When I ask MCP for "tools/list"

  Scenario: The open and capped ranges read the same in every tool that takes them
    Then the descriptions of "list_mail_threads, list_social_posts, list_webmentions" each hold "Give from, to or both as YYYY-MM-DD to keep only those days; both days sit inside the range"
    And the descriptions of "read_analytics, summarize_activity" each hold "Give from and to as YYYY-MM-DD; both days sit inside the range, which runs at most 366 days"

  Scenario: The untrusted text of webmentions and deliveries reads the same in every tool that shows it
    Then the descriptions of "list_webmentions, read_webmention" each hold "Each webmention's source, author name, author URL and excerpt, taken from the sender's page, come marked untrusted."
    And the descriptions of "read_social_post" each hold "Each delivery's error quotes what the network answered, so it comes marked untrusted"

  Scenario: upload_photo names the size limit the contract checks
    Then the description of "upload_photo" ends with "up to 20 MB"
