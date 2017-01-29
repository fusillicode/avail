class Event < ActiveRecord::Base
  TIME_SLOT_SIZE = 30.minutes

  def self.availabilities(from_day)
    Availabilities.new(from_day).get
  end

  def self.for_availabilites_retrival(from, to, week_days)
    where("#{not_weekly_recurring_condition} OR #{weekly_recurring_condition}",
          from: from, to: to, week_days: week_days)
      .order :starts_at
  end

  def self.not_weekly_recurring_condition
    "((weekly_recurring IS NULL OR weekly_recurring = 'f') AND starts_at BETWEEN :from AND :to)"
  end

  def self.weekly_recurring_condition
    "(weekly_recurring == 't' AND starts_at <= :to AND strftime('%w', starts_at) IN (:week_days))"
  end
end
