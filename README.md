## Goal

The goal is to write an algorithm that checks the availabilities of an agenda depending of the events attached to it.
The main method has a start date for input and is looking for the availabilities of the next 7 days.

They are two kinds of events:

 - 'opening', are the openings for a specific day and they can be recurring week by week.
 - 'appointment', times when there is already a bookening.

To init the project:

``` sh
rails new avail
rails g model event starts_at:datetime ends_at:datetime kind:string weekly_recurring:boolean
```

The mission :
 - in rails 4.2
 - sqlite compatible
 - to make the following unit test pass
 - to add tests for the edge cases
