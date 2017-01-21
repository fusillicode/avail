# FIXME: this is just a draft created from `Events.availabilities`
class Availabilities
  attr_reader :from, :to

  def initialize(from, to = nil)
    @from = from
    @to   = to || from + 6.days
  end

  def get
    appointments = events_of_interest.select { |event| event.kind == 'appointment' }
    openings.map do |opening_day, opening_times|
      {
        date:  opening_day,
        slots: availabilities(squashed_opening_times(opening_times), appointments)
      }
    end
  end

  private

  def temporal_frame
    (from..to).to_a
  end

  def temporal_frame_week_days
    temporal_frame.group_by(&:wday).keys.map &:to_s
  end

  # Merging adiacent opening_times to build NON adiacent ones
  def squashed_opening_times(opening_times)
    opening_times = opening_times.to_a
    opening_times.size.odd? ? [opening_times.first, opening_times.last] : opening_times
  end

  # To work correctly the appointments should be ordered by starts_at!
  def availabilities(squashed_opening_times, appointments)
    squashed_opening_times.each_slice(2).inject([]) do |memo, opening|
      last_availability_bound = opening.first
      appointments.each do |appointment|
        if appointment.starts_at.to_date != opening_day.to_date && last_availability_bound != opening.last
          memo += format_slot([last_availability_bound, opening.last])
          break
        elsif last_availability_bound != (appointment_start = appointment.starts_at)
          memo += format_slot([last_availability_bound, appointment_start])
        end
        last_availability_bound = appointment.ends_at
      end
      memo += format_slot([last_availability_bound, opening.last]) if last_availability_bound != opening.last
      memo
    end
  end

  def openings
    openings = Hash[temporal_frame.map { |day| [day, SortedSet.new] }]

    # Populute the temporal frame with the normal openings together with the
    # weekly recurring "actualized"
    events_of_interest.select { |event| event.kind == 'opening' }.each do |opening|
      if opening.weekly_recurring
        temporal_frame.select { |date| date.wday == opening.starts_at.wday }.each do |actualized_opening_date|
          openings[actualized_opening_date] = openings[actualized_opening_date].merge [opening.starts_at, opening.ends_at]
        end
      else
        openings[opening.starts_at] = openings[opening.starts_at].merge [opening.starts_at, opening.ends_at]
      end
      openings
    end
  end

  def events_of_interest
    Event.where("#{events_of_interest_not_weekly_recurring} OR #{events_of_interest_weekly_recurring}",
                from: from, to: to, week_days: temporal_frame_week_days).order :starts_at
  end

  def events_of_interest_not_weekly_recurring
    "((weekly_recurring IS NULL OR weekly_recurring = 'f') AND starts_at BETWEEN :from AND :to)"
  end

  def events_of_interest_weekly_recurring
    "(weekly_recurring == 't' AND starts_at <= :to AND strftime('%w', starts_at) IN (:week_days))"
  end

  def format_slot(slot)
    slot.map { |bound| bound.strftime('%-l:%M') }
  end
end
