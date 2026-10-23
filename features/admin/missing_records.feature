Feature: Admin records that are gone
  A POST that names a record that is not there answers 404.

  Scenario Outline: A POST to /admin<path> for a record that is gone is not found
    Given I am signed in to the admin
    When I post to "/admin<path>" with the fields "<fields>"
    Then the answer is 404

    Examples:
      | path                              | fields                                                                 |
      | /decisions/999999                 | decision[title]=Pick&decision[problem]=Why                             |
      | /decisions/999999/drop            | decision[reason]=No need                                               |
      | /decisions/999999/options         | option[title]=Sidekiq&option[body]=                                    |
      | /decisions/999999/options/999999  | option[title]=Sidekiq&option[body]=                                    |
      | /decisions/999999/reopen          | decision[reason]=Again                                                 |
      | /decisions/999999/resolve         | decision[option_id]=1&decision[reason]=It runs                         |
      | /journal/999999                   | entry[body]=after                                                      |
      | /journal/999999/delete            |                                                                        |
      | /messages/999999/mark/read        |                                                                        |
      | /people/999999                    | person[name]=Ada&person[key]=ada&person[mastodon_handle]=@ada@ruby.social |
      | /people/999999/delete             |                                                                        |
      | /posts/999999                     | post[title]=Hello&post[body]=hi                                        |
      | /posts/999999/delete              |                                                                        |
      | /projects/999999                  | project[name]=Blog                                                     |
      | /projects/999999/archive          |                                                                        |
      | /projects/999999/restore          |                                                                        |
      | /projects/work/999999/delete      |                                                                        |
      | /tags/999999                      | tag[name]=hanami                                                       |
      | /tags/999999/delete               |                                                                        |
      | /tasks/999999                     | task[title]=mow the lawn                                               |
      | /tasks/999999/cancel              |                                                                        |
      | /tasks/999999/complete            |                                                                        |
      | /tasks/999999/delete              |                                                                        |
      | /tasks/999999/links               | link[key]=T-1&link[kind]=blocks                                        |
      | /tasks/2147483648                 | task[title]=mow the lawn                                               |
      | /tasks/2147483648/links           | link[kind]=blocks&link[other_id]=1                                     |
      | /tasks/999999/move/someday        |                                                                        |
      | /tasks/999999/move/today          |                                                                        |
      | /tasks/999999/place               |                                                                        |
      | /tasks/999999/reopen              |                                                                        |
      | /tasks/999999/schedule            |                                                                        |
      | /tasks/999999/start               |                                                                        |
      | /tasks/999999/stop                |                                                                        |
      | /tasks/sprints/999999/delete      |                                                                        |
      | /webmentions/999999/approve       |                                                                        |
      | /webmentions/999999/ignore        |                                                                        |
      | /webmentions/999999/spam          |                                                                        |
