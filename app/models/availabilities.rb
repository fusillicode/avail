class Availabilities
  TIME_SLOT_SIZE = 30.minutes

  attr_reader :from, :to

  def initialize(from, to = nil)
    @from = from
    @to   = to || from + 6.days
  end

  def get
    events       = Event.for_availbilites_calculation from, to, week_days_of_temporal_frame
    appointments = events.select { |event| event.kind == 'appointment' }
    openings_from_events(events).map do |opening_day, opening_time_slots|
      {
        date:  opening_day,
        slots: format_available_time_slots(
          available_time_slots(opening_day, opening_time_slots, appointments)
        )
      }
    end
  end

  private

  def temporal_frame
    (from..to).to_a
  end

  def week_days_of_temporal_frame
    temporal_frame.group_by(&:wday).keys.map &:to_s
  end

  def openings_from_events(events)
    # Prepare the temporal frame for the openings and populate the temporal
    # frame with the normal openings together with the weekly recurring
    # "actualized"
    Hash[temporal_frame.map { |day| [day, SortedSet.new] }].tap do |openings|
      events.select { |event| event.kind == 'opening' }.each do |opening|
        if opening.weekly_recurring
          temporal_frame.select { |date| date.wday == opening.starts_at.wday }.each do |actualized_opening_date|
            openings[actualized_opening_date] << time_slots_for_event(opening)
          end
        else
          openings[opening.starts_at] << time_slots_for_event(opening)
        end
        openings
      end
    end
  end

  def available_time_slots(opening_day, opening_time_slots, appointments)
    opening_time_slots.inject(SortedSet.new) do |memo, opening_time_slots|
      memo = opening_time_slots
      appointments.each do |appointment|
        break if appointment.starts_at.to_date != opening_day.to_date
        appointment_time_slots = SortedSet.new time_slots_for_event(appointment)
        memo -= appointment_time_slots
        appointments.delete appointment
      end
      memo
    end
  end

  def time_slots_for_event(event)
    SortedSet.new((event.starts_at.to_i..event.ends_at.to_i).step(TIME_SLOT_SIZE).map do |unix_time|
      # FIXME: the `utc` conversion should be maybe replaced with a conversion considering the
      # actual timezone...
      time = Time.at(unix_time).utc
      [time.hour, time.min]
    end.tap(&:pop))
  end

  def format_available_time_slots(availabilities)
    availabilities.to_a.map { |time_slot| format_time_slot(time_slot) }
  end

  def format_time_slot(time)
    "#{time.first}:" + time.last.to_s.ljust(2, '0')
  end
end
