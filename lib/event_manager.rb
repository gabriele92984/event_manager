require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phone_number(phone_number)
  cleaned_number = phone_number.gsub(/[^0-9]/, '')

  case cleaned_number.size
  when 10
    cleaned_number # Good number
  when 11 
    cleaned_number.start_with?('1') ? cleaned_number[1..-1] : nil # Trim leading '1'
  else
    nil # Bad number for all other cases
  end
end

def parse_regdate(regdate)
  begin
    Time.strptime(regdate, "%m/%d/%y %H:%M") # Return full Time object
  rescue ArgumentError => e
    puts "Error parsing registration date '#{regdate}': #{e.message}"
    nil # Return nil or handle as appropriate
  end
end

def peak_registration_hours(registration_hours)
  hour_counts = registration_hours.tally # Tally occurrences of each hour
  peak_hours = hour_counts.sort_by { |hour, count| -count }.take(3) # Sort by count and take top 3
  peak_hours # Return array of [hour, count]
end

def day_of_week_targeting(registration_dates)
  day_names = registration_dates.map { |date| date.strftime("%A") } # Get day names from dates
  day_counts = day_names.tally # Use tally to count occurrences of each day
  day_counts.sort_by { |day, count| -count }.take(3) # Sort by count and take top 3 days
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

registration_dates = [] # Changed to store full date objects

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_number(row[:homephone]) # Clean phone numbers
  registration = row[:regdate]

  date = parse_regdate(registration)

  if date # Only add if date is valid (not nil)
    registration_dates << date # Collect registration dates as full DateTime objects
  end

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)

  puts "#{name} #{zipcode} #{phone} #{registration}" # Assignment check
end

# Calculate and display peak registration hours after processing all attendees
peak_hours_with_counts = peak_registration_hours(registration_dates.map(&:hour))

puts "----------------------------------------"
puts "Peak registration hours and users count:"
peak_hours_with_counts.each do |hour, count|
  puts "Hour: #{hour}, Count: #{count}"
end

# Calculate and display peak registration days after processing all attendees
peak_days_with_counts = day_of_week_targeting(registration_dates)

puts "----------------------------------------"
puts "Peak registration days and users count:"
peak_days_with_counts.each do |day, count|
  puts "Day: #{day}, Count: #{count}"
end
