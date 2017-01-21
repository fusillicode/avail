class Event < ActiveRecord::Base
  TIME_SLOT_SIZE = 30.minutes

  def self.availabilities(from_day)
    to_day         = from_day + 6.days
    temporal_frame = (from_day..to_day).to_a
    week_days      = temporal_frame.group_by(&:wday).keys.map &:to_s

    events_of_interest = where("
      ((weekly_recurring IS NULL OR weekly_recurring = 'f') AND starts_at BETWEEN :from AND :to)
      OR
      (weekly_recurring == 't' AND starts_at <= :to AND strftime('%w', starts_at) IN (:week_days))",
                               from: from_day, to: to_day, week_days: week_days).order :starts_at

    # Prepare the temporal frame for the openings
    openings = Hash[temporal_frame.map { |day| [day, SortedSet.new] }]

    # Populute the temporal frame with the normal openings together with the
    # weekly recurring "actualized"
    events_of_interest.select { |event| event.kind == 'opening' }.each do |opening|
      if opening.weekly_recurring
        temporal_frame.select { |date| date.wday == opening.starts_at.wday }.each do |actualized_opening_date|
          openings[actualized_opening_date] << time_slots_for_event(opening)
        end
      else
        openings[opening.starts_at] << time_slots_for_event(opening)
      end
      openings
    end

    appointments = events_of_interest.select { |event| event.kind == 'appointment' }

    openings.map do |opening_day, opening_time_slots|

      availabilities = opening_time_slots.inject(SortedSet.new) do |memo, opening_time_slots|
        memo = opening_time_slots

        appointments.each do |appointment|
          break if appointment.starts_at.to_date != opening_day.to_date
          appointment_time_slots = SortedSet.new self.time_slots_for_event(appointment)
          memo = memo - appointment_time_slots
          appointments.delete appointment
        end

        memo
      end.to_a.map { |time_slot| format_time_slot(time_slot) }

      { date: opening_day, slots: availabilities }
    end
  end

  def self.time_slots_for_event event
    SortedSet.new((event.starts_at.to_i..event.ends_at.to_i).step(self::TIME_SLOT_SIZE).map do |unix_time|
      time = Time.at(unix_time).utc
      [time.hour, time.min]
    end.tap { |o| o.pop })
  end

  def self.format_time_slot time
    "#{time.first}:" + "#{time.last}".ljust(2, '0')
  end
end
