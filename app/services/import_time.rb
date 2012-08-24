require 'active_support/core_ext'

class ImportTime
  attr_reader :start_datetime, :end_date, :last_scheduled_at, :frequency, :current_time

  def initialize(start_datetime, end_date, last_scheduled_at, frequency, current_time)
    @start_datetime = start_datetime
    @end_date = end_date
    @last_scheduled_at = last_scheduled_at
    @frequency = frequency
    @current_time = current_time
  end

  def next_import_time
    target_datetime = last_scheduled_at.blank? ? start_datetime : add_interval(last_scheduled_at)

    while(target_datetime < current_time)
      target_datetime = add_interval(target_datetime)
    end

    target_datetime.to_date > end_date ? nil : target_datetime
  end

  def add_interval(datetime)
    case frequency.to_s
      when 'daily' then datetime.tomorrow
      when 'weekly' then datetime + 7.days
      when 'monthly' then datetime.next_month
    end
  end
end
