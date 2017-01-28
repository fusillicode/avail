require 'test_helper'

class EventTest < ActiveSupport::TestCase
  test 'one simple test example (enriched with some additional overlaps...just to be sure)' do
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-07-28 09:30'), ends_at: DateTime.parse('2014-07-28 12:30'), weekly_recurring: true
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-14 09:30'), ends_at: DateTime.parse('2014-08-14 12:30'), weekly_recurring: true
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-04 09:30'), ends_at: DateTime.parse('2014-08-04 12:30'), weekly_recurring: true
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 10:30'), ends_at: DateTime.parse('2014-08-11 11:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')

    assert_equal Date.new(2014, 8, 10), availabilities[0][:date]
    assert_equal [], availabilities[0][:slots]
    assert_equal Date.new(2014, 8, 11), availabilities[1][:date]
    assert_equal ['9:30', '10:00', '11:30', '12:00'], availabilities[1][:slots]
    assert_equal ['9:30', '10:00', '10:30', '11:00', '11:30', '12:00'], availabilities[4][:slots]
    assert_equal Date.new(2014, 8, 16), availabilities[6][:date]
    assert_equal 7, availabilities.length
  end

  test 'events at the beginning and end of an opening' do
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-07-28 09:30'), ends_at: DateTime.parse('2014-07-28 15:30'), weekly_recurring: true
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 09:30'), ends_at: DateTime.parse('2014-08-11 11:30')
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 13:30'), ends_at: DateTime.parse('2014-08-11 15:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')

    7.times.each do |week_day|
      next if week_day == 1
      assert_empty availabilities[week_day][:slots]
    end

    assert_equal ['11:30', '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00'], availabilities[1][:slots]
  end
end
