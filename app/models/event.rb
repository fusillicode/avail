class Event < ActiveRecord::Base
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
    openings = Hash[temporal_frame.map { |day| [day.strftime('%Y/%m/%d'), SortedSet.new] }]

    # Populute the temporal frame with the normal openings together with the
    # weekly recurring "actualized"
    events_of_interest.select { |event| event.kind == 'opening' }.each do |opening|
      if opening.weekly_recurring
        temporal_frame.select { |date| date.wday == opening.starts_at.wday }.each do |actualized_opening_date|
          openings[actualized_opening_date.strftime('%Y/%m/%d')] = openings[actualized_opening_date.strftime('%Y/%m/%d')].merge [opening.starts_at.strftime('%I:%M'), opening.ends_at.strftime('%I:%M')]
        end
      else
        openings[opening.starts_at.strftime('%Y/%m/%d')] = memo[opening.starts_at.strftime('%Y/%m/%d')].merge [opening.starts_at.strftime('%I:%M'), opening.ends_at.strftime('%I:%M')]
      end
      openings
    end

    appointments = events_of_interest.select { |event| event.kind == 'appointment' }

    openings.map do |opening_day, opening_times|
      # Merging adiacent opening_times to build NON adiacent ones
      opening_times = opening_times.to_a
      opening_times = opening_times.size.odd? ? [opening_times.first, opening_times.last] : opening_times

      availabilities = opening_times.each_slice(2).inject([]) do |memo, opening|
        last_availability_bound = opening.first
        # To work correctly the appointments should be ordered by starts_at!
        appointments.each do |appointment|
          if appointment.starts_at.strftime('%Y/%m/%d') != opening_day && last_availability_bound != opening.last
            memo += [last_availability_bound, opening.last]
            break
          elsif last_availability_bound != (appointment_start = appointment.starts_at.strftime('%I:%M'))
            memo += [last_availability_bound, appointment_start]
          end
          last_availability_bound = appointment.ends_at.strftime('%I:%M')
        end
        memo += [last_availability_bound, opening.last] if last_availability_bound != opening.last
        memo
      end

      { date: opening_day, slots: availabilities }
    end
  end
end

# [{"date":"2014/08/04","slots":["12:00","13:30"]},{"date":"2014/08/05","slots":["09:00", "09:30"]},
# {"date":"2014/08/06","slots":[]},{"date":"2014/08/07","slots":["15:30","16:30","17:00"]},
# {"date":"2014/08/08","slots":[]},{"date":"2014/08/09","slots":["14:00", "14:30"],"substitution":null},
# {"date":"2015/08/10","slots":[]}]
