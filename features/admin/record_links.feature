Feature: Admin record links
  Each record page with a Linked section lists what links to it, finds more to link, and adds and removes links.

  Background:
    Given I am signed in to the admin
    And a record link task titled "Move the server"
    And a record link task titled "Order the rack"

  Scenario Outline: The Linked section says nothing is linked yet
    Given a record link <kind> titled "<title>"
    When I visit "<page>"
    Then the record page has ".record-links .hint" reading "Nothing linked yet."

    Examples:
      | kind          | title                | page                                 |
      | post          | On hosting           | /admin/posts/1/edit                  |
      | project       | homelab              | /admin/projects/1/edit               |
      | commit        | app: move the server | /admin/commits/1                     |
      | pull_request  | Move the server      | /admin/pull-requests/1               |
      | social_post   | A draft to send      | /admin/social?filter=drafts&edit=1   |
      | journal_entry | Packed the rack      | /admin/journal?to=2026-09-30&edit=1  |
      | work_entry    | Engineer             | /admin/projects?filter=work&edit=1   |

  Scenario Outline: The Linked section groups its links by kind, each linking to its record, with a remove on each
    Given a record link <kind> titled "<title>"
    And a record link decision titled "Pick a host"
    And the record links tie the <kind> 1 to the task 1
    And the record links tie the <kind> 1 to the decision 1
    When I visit "<page>"
    Then the record links group "Tasks" links "Move the server" to "/admin/tasks/1"
    And the record links group "Decisions" links "Pick a host"
    And the record page has ".record-links form[action='/admin/records/<kind>/1/links/task/1/delete']"

    Examples:
      | kind          | title                | page                                 |
      | post          | On hosting           | /admin/posts/1/edit                  |
      | project       | homelab              | /admin/projects/1/edit               |
      | commit        | app: move the server | /admin/commits/1                     |
      | pull_request  | Move the server      | /admin/pull-requests/1               |
      | social_post   | A draft to send      | /admin/social?filter=drafts&edit=1   |
      | journal_entry | Packed the rack      | /admin/journal?to=2026-09-30&edit=1  |
      | work_entry    | Engineer             | /admin/projects?filter=work&edit=1   |

  Scenario Outline: The picker finds a task by its title, searches from the same page and posts the link from each match
    Given a record link <kind> titled "<title>"
    When I visit "<page>"
    Then the record page's ".record-links form.record-picker-find" has the action "<base>"
    When I visit "<search>"
    Then the record picker offers "Move the server"
    And the record page has ".record-links form[action='<records>'] button.record-picker-target"

    Examples:
      | kind          | title                | page                                | base                   | search                                            | records                         |
      | post          | On hosting           | /admin/posts/1/edit                 | /admin/posts/1/edit    | /admin/posts/1/edit?record_q=server                 | /admin/posts/1/records          |
      | project       | homelab              | /admin/projects/1/edit              | /admin/projects/1/edit | /admin/projects/1/edit?record_q=server              | /admin/projects/1/records       |
      | commit        | app: move the server | /admin/commits/1                    | /admin/commits/1       | /admin/commits/1?record_q=server                    | /admin/commits/1/records        |
      | pull_request  | Move the server      | /admin/pull-requests/1              | /admin/pull-requests/1 | /admin/pull-requests/1?record_q=server              | /admin/pull-requests/1/records  |
      | social_post   | A draft to send      | /admin/social?filter=drafts&edit=1  | /admin/social          | /admin/social?filter=drafts&edit=1&record_q=server  | /admin/social/1/records         |
      | journal_entry | Packed the rack      | /admin/journal?to=2026-09-30&edit=1 | /admin/journal         | /admin/journal?to=2026-09-30&edit=1&record_q=server | /admin/journal/1/records        |
      | work_entry    | Engineer             | /admin/projects?filter=work&edit=1  | /admin/projects        | /admin/projects?filter=work&edit=1&record_q=server  | /admin/projects/work/1/records  |

  Scenario Outline: The picker leaves out a task it already links to
    Given a record link <kind> titled "<title>"
    And the record links tie the <kind> 1 to the task 1
    When I visit "<search>"
    Then the record picker offers ""

    Examples:
      | kind          | title                | search                                            |
      | post          | On hosting           | /admin/posts/1/edit?record_q=server                 |
      | project       | homelab              | /admin/projects/1/edit?record_q=server              |
      | commit        | app: move the server | /admin/commits/1?record_q=server                    |
      | pull_request  | Move the server      | /admin/pull-requests/1?record_q=server              |
      | social_post   | A draft to send      | /admin/social?filter=drafts&edit=1&record_q=server  |
      | journal_entry | Packed the rack      | /admin/journal?to=2026-09-30&edit=1&record_q=server |
      | work_entry    | Engineer             | /admin/projects?filter=work&edit=1&record_q=server  |

  Scenario Outline: Adding links ties several records, shows on the other record and comes back to the record
    Given a record link <kind> titled "<title>"
    And a record link post titled "Another post"
    When I post the record link form to "<records>" with "<fields>&record[other_kind]=task&record[other_id]=1"
    Then the record link post answers 302
    And the record link post lands on "<back>"
    And the record page has "[data-toast]" reading "Record linked"
    When I post the record link form to "<records>" with "<fields>&record[other_kind]=post&record[other_id]=<post>"
    Then the record links of the <kind> 1 read "post <post>, task 1"
    And the record links of the task 1 read "<kind> 1"

    Examples:
      | kind          | title                | records                        | back                                | fields               | post |
      | post          | On hosting           | /admin/posts/1/records         | /admin/posts/1/edit                 |                      | 2    |
      | project       | homelab              | /admin/projects/1/records      | /admin/projects/1/edit              |                      | 1    |
      | commit        | app: move the server | /admin/commits/1/records       | /admin/commits/1                    |                      | 1    |
      | pull_request  | Move the server      | /admin/pull-requests/1/records | /admin/pull-requests/1              |                      | 1    |
      | social_post   | A draft to send      | /admin/social/1/records        | /admin/social?filter=drafts&edit=1  | filter=drafts&edit=1 | 1    |
      | journal_entry | Packed the rack      | /admin/journal/1/records       | /admin/journal?to=2026-09-30&edit=1 | to=2026-09-30&edit=1 | 1    |
      | work_entry    | Engineer             | /admin/projects/work/1/records | /admin/projects?filter=work&edit=1  | filter=work&edit=1   | 1    |

  Scenario Outline: Adding a link to a record that is not there answers 404
    Given a record link <kind> titled "<title>"
    When I post the record link form to "<records>" with "record[other_kind]=task&record[other_id]=1"
    Then the record link post answers 404

    Examples:
      | kind          | title                | records                        |
      | post          | On hosting           | /admin/posts/0/records         |
      | project       | homelab              | /admin/projects/0/records      |
      | commit        | app: move the server | /admin/commits/0/records       |
      | pull_request  | Move the server      | /admin/pull-requests/0/records |
      | social_post   | A draft to send      | /admin/social/0/records        |
      | journal_entry | Packed the rack      | /admin/journal/0/records       |
      | work_entry    | Engineer             | /admin/projects/work/0/records |

  Scenario Outline: Adding a record already linked says so beside the picker, keeps the query and writes nothing
    Given a record link <kind> titled "<title>"
    And the record links tie the <kind> 1 to the task 1
    When I post the record link form to "<records>" with "<fields>&record[other_kind]=task&record[other_id]=1&record_q=server"
    Then the record link post answers 422
    And the record page's ".record-links #<scope>-other-id-error" reads "These two are already linked."
    And the record page's "#<scope>-other-id" holds "server"
    And the record links of the <kind> 1 read "task 1"

    Examples:
      | kind          | title                | records                        | fields               | scope                  |
      | post          | On hosting           | /admin/posts/1/records         |                      | post-1-record          |
      | project       | homelab              | /admin/projects/1/records      |                      | project-1-record       |
      | commit        | app: move the server | /admin/commits/1/records       |                      | commit-1-record        |
      | pull_request  | Move the server      | /admin/pull-requests/1/records |                      | pull-request-1-record  |
      | social_post   | A draft to send      | /admin/social/1/records        | filter=drafts&edit=1 | social-post-1-record   |
      | journal_entry | Packed the rack      | /admin/journal/1/records       | to=2026-09-30&edit=1 | journal-entry-1-record |
      | work_entry    | Engineer             | /admin/projects/work/1/records | filter=work&edit=1   | work-entry-1-record    |

  Scenario Outline: Removing a link clears it, comes back to the record and says so
    Given a record link <kind> titled "<title>"
    And the record links tie the <kind> 1 to the task 1
    When I post the record link form to "/admin/records/<kind>/1/links/task/1/delete" with "<fields>"
    Then the record link post answers 302
    And the record link post lands on "<back>"
    And the record page has "[data-toast]" reading "Link removed"
    And the record links of the <kind> 1 read "nothing"

    Examples:
      | kind          | title                | back                                | fields               |
      | post          | On hosting           | /admin/posts/1/edit                 |                      |
      | project       | homelab              | /admin/projects/1/edit              |                      |
      | commit        | app: move the server | /admin/commits/1                    |                      |
      | pull_request  | Move the server      | /admin/pull-requests/1              |                      |
      | social_post   | A draft to send      | /admin/social?filter=drafts&edit=1  | filter=drafts&edit=1 |
      | journal_entry | Packed the rack      | /admin/journal?to=2026-09-30&edit=1 | to=2026-09-30&edit=1 |
      | work_entry    | Engineer             | /admin/projects?filter=work&edit=1  | filter=work&edit=1   |

  Scenario Outline: Removing a link that is not there, an ID too large to store or a kind it does not know answers 404
    Given a record link <kind> titled "<title>"
    And the record links tie the <kind> 1 to the task 1
    When I post the record link form to "/admin/records/<kind>/1/links/task/2/delete" with "<fields>"
    Then the record link post answers 404
    When I post the record link form to "/admin/records/<kind>/1/links/task/2147483648/delete" with "<fields>"
    Then the record link post answers 404
    When I post the record link form to "/admin/records/<kind>/1/links/person/1/delete" with "<fields>"
    Then the record link post answers 404
    And the record links of the <kind> 1 read "task 1"

    Examples:
      | kind          | title                | fields               |
      | post          | On hosting           |                      |
      | project       | homelab              |                      |
      | commit        | app: move the server |                      |
      | pull_request  | Move the server      |                      |
      | social_post   | A draft to send      | filter=drafts&edit=1 |
      | journal_entry | Packed the rack      | to=2026-09-30&edit=1 |
      | work_entry    | Engineer             | filter=work&edit=1   |

  Scenario: Removing a link from a mail thread, which has no Linked section, answers 404 and keeps the link
    Given a record link mail_thread titled "Lunch on Friday"
    And the record links tie the mail_thread 1 to the task 1
    When I post the record link form to "/admin/records/mail_thread/1/links/task/1/delete"
    Then the record link post answers 404
    And the record links of the mail_thread 1 read "task 1"

  Scenario: The social composer leaves the section off a new post
    When I visit "/admin/social"
    Then the record page has no ".record-links"

  Scenario: A journal entry offers a way in to its links and keeps the section off entries it is not editing
    Given a record link journal_entry titled "Packed the rack"
    When I visit "/admin/journal"
    Then the record page links "Links" to "/admin/journal?to=2026-09-30&edit=1"
    And the record page has no ".record-links"

  Scenario: A journal entry's links open its edit form with the section
    Given a record link journal_entry titled "Packed the rack"
    When I visit "/admin/journal?to=2026-09-30&edit=1"
    Then the record page has "form.journal-edit[action='/admin/journal/1']:not([hidden])"
    And the record page has ".journal-entry .journal-links .record-links"

  Scenario: A refused journal edit keeps the section
    Given a record link journal_entry titled "Packed the rack"
    When I post the record link form to "/admin/journal/1" with "entry[body]= "
    Then the record page has ".journal-entry .journal-links .record-links"

  Scenario: A work entry offers a way in from its row, names itself on the section and marks its row
    Given a record link work_entry titled "Engineer"
    When I visit "/admin/projects?filter=work"
    Then the record page links "Links" to "/admin/projects?filter=work&edit=1"
    When I visit "/admin/projects?filter=work&edit=1"
    Then the record page has ".record-links" reading "Engineer at Rackspace"
    And the record page has "a[aria-current='true'][href='/admin/projects?filter=work&edit=1']"

  Scenario Outline: A record page with a Linked section has no axe breaches
    Given a record link <kind> titled "<title>"
    And the record links tie the <kind> 1 to the task 1
    When I visit "<page>"
    Then the page has no axe breaches in light or dark

    Examples:
      | kind          | title                | page                                              |
      | post          | On hosting           | /admin/posts/1/edit?record_q=server                 |
      | project       | homelab              | /admin/projects/1/edit?record_q=server              |
      | commit        | app: move the server | /admin/commits/1?record_q=server                    |
      | pull_request  | Move the server      | /admin/pull-requests/1?record_q=server              |
      | social_post   | A draft to send      | /admin/social?filter=drafts&edit=1&record_q=server  |
      | journal_entry | Packed the rack      | /admin/journal?to=2026-09-30&edit=1&record_q=server |
      | work_entry    | Engineer             | /admin/projects?filter=work&edit=1&record_q=server  |
