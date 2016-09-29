#!/usr/bin/env ruby

#
# Copyright (c) 2016 Carlos A. Carro Duplá (@ccarrodupla)
# released under The MIT license (MIT) http://opensource.org/licenses/MIT
#

class ContribMap

  require 'net/http'

  # It takes a Hash of options, just to avoid the annoying questioning to set it up for the same values every time.
  #  Change the default options if you wish
  def initialize(received_options = {})
    required_data = [:github_url, :username, :repo_to_change]
    defaults = {
                  github_url:     'https://github.com/',
                  repo_to_change: 'contrib_mapper',
                  username:       'carloscd',
                }
    questions = {
                  github_url:     "Enter GitHub URL#{" (leave blank to use #{defaults[:github_url]})" if defaults[:github_url]}",
                  repo_to_change: "Repository to be used to send changes#{" (leave blank to use #{defaults[:repo_to_change]})" if defaults[:repo_to_change]}",
                  username:       'Your GitHub user name'
                }
    required = defaults.keys
    set_data(true, required_data, defaults, questions, [], received_options)

    my_contributions_calendar = get_contributions_calendar(@username)
    # puts 'my_contributions_calendar:'
    # puts '*********'
    # puts my_contributions_calendar.to_s
    # puts '*********'
    my_max_daily_commits = calendar_max_value my_contributions_calendar
    puts " Your maximum number of daily commits is: #{my_max_daily_commits}"
    @faking_multiplier = scaling_multiplier(my_max_daily_commits)
    puts " The faking multiplier is: '#{@faking_multiplier}'"
  end

  def random_map(received_options = {})
    defaults = { output_file: 'random.sh', map_file: 'random.txt' }
    questions = {
                  output_file: 'The output shell script',
                  map_file:    'Map file to be generated'
                }
    set_data(true, defaults.keys, defaults, questions, [], received_options)
    # Here I should have the instance variables:
    #  @github_url, @repo_to_change, @username
    #  @output_file, @map_file

    random_map = random_contribution_map
    puts 'random_contribution_map:'
    puts '*********'
    puts format_matrix_to_output(random_map)
    puts '*********'
    
    save_contribution_map random_map, @map_file

    random_map = map_multiply(random_map, @faking_multiplier)
    puts "random_contribution_map times @faking_multiplier(#{@faking_multiplier}):"
    puts '*********'
    puts format_matrix_to_output(random_map)
    puts '*********'

    start_date = calendar_start_date
    puts "start_date: [#{start_date}]"
    shell_script = contribution_shell_script(random_map, start_date, @username, @repo_to_change, 'git@github.com')

    # puts '------'
    # puts 'Script:'
    # puts '*********'
    # puts shell_script
    # puts '*********'

    open(@output_file, 'w'){ |f| f << shell_script }
    puts "#{@output_file} saved."
    puts "Create a repo called #{@github_url}#{@repo_to_change} and run the script"
  end

  def copy_user(received_options = {})
    defaults = { user_to_copy: 'tenderlove', output_file: 'tenderlove.sh' }
    questions = { copy_user:   'Use the shape of the map of this user',
                  output_file: 'The output shell script' }
    optionals = [ :map_file ]
    set_data(true, defaults.keys, defaults, questions, optionals, received_options)
    # Here I should have the instance variables:
    #  @github_url, @repo_to_change, @username
    #  @user_to_copy, @output_file
    #  And optional: @map_file

    # TODO: Get the user_to_copy's contrib map:
    the_map_to_copy = get_contributions_calendar(@user_to_copy)
    puts "#{@user_to_copy}'s contribution map:"
    puts '*********'
    puts format_matrix_to_output(the_map_to_copy)
    puts '*********'

    copy_user_max_daily_commits = calendar_max_value the_map_to_copy
    puts "The maximum number of daily commits of #{@copy_user} is: #{copy_user_max_daily_commits}"
    puts "We will try to match #{@copy_user}'s repository map"

    # Calendar for values 0..4, the contribution calendar to use only numbers 0..4
    the_map_to_copy = normalize_calendar(the_map_to_copy)
    puts "#{@user_to_copy}'s normalized map (values 0..4):"
    puts '*********'
    puts format_matrix_to_output(the_map_to_copy)
    puts '*********'

    save_contribution_map(the_map_to_copy, @map_file, @user_to_copy) if @map_file

    the_map_to_copy = map_multiply(the_map_to_copy, @faking_multiplier)
    puts "the_map_to_copy times @faking_multiplier(#{@faking_multiplier}):"
    puts '*********'
    puts format_matrix_to_output(the_map_to_copy)
    puts '*********'

    start_date = calendar_start_date
    puts "start_date: [#{start_date}]"
    shell_script = contribution_shell_script(the_map_to_copy, start_date, @username, @repo_to_change, 'git@github.com')

    # puts '------'
    # puts 'Script:'
    # puts '*********'
    # puts shell_script
    # puts '*********'

    open(@output_file, 'w'){ |f| f << shell_script }
    puts "#{@output_file} saved."
    puts "Create a repo called #{@github_url}#{@repo_to_change} and run the script"

  end

  private

  # --General utility methods:

  # Generates instance variables, and if needed, asks for user's input:
  def set_data(verbose = false, required = [], defaults = {}, questions = {}, optionals = [], received = {})
    # Set the options:
    keys_to_set = required
    optionals.each do |opt|
      if received[opt]
        keys_to_set << opt
      end
    end
    # puts '-------'
    # puts 'Received info:'
    # puts "  verbose:   #{verbose}"
    # puts "  required:  #{required}"
    # puts "  defaults:  #{defaults}"
    # puts "  questions: #{questions}"
    # puts "  optionals: #{optionals}"
    # puts "  received:  #{received}"
    # puts '--'
    # puts "keys_to_set: #{keys_to_set}"
    # puts '--'
    all_data = {}
    keys_to_set.each do |key|
      all_data[key] = received[key] || defaults[key]
    end
    # puts "To set (from received + defaults): #{all_data}"
    # puts '-------'
    # puts '--'
    keys_to_set.each do |key|
      if all_data[key]
        given_value = all_data[key]
      else
        puts "#{questions[key] || key.to_s}: "
        given_value = gets.chomp
      end
      instance_variable_set "@#{key}".to_sym, (given_value.empty? ? nil : given_value)
    end
    if verbose
      # puts 'Setup: '
      puts
      keys_to_set.each do |data_collected|
        puts " - #{snakecase_prettifier data_collected}: '#{instance_variable_get "@#{data_collected}".to_sym}'"
      end
      unless all_string_with_values?(@github_url, @username, @repo_to_change)
        puts 'Important informstion missing: either the GitHub URL, the username, or the repo to change.'
      end
    end
  end

  def snakecase_prettifier(sneakey)
    sneakey.to_s.capitalize.gsub('_', ' ')
  end

  def present?(a_string)
    a_string.is_a?(String) && !a_string.empty?
  end

  def all_string_with_values?(*array_of_strings)
    return false unless array_of_strings.is_a? Array
    array_of_strings == array_of_strings.select{|s| present?(s)}
  end

  def format_matrix_to_output(matrix)
    result = '['
    matrix.each_with_index do |row, index|
      result << (row.to_s.gsub(' ', '') + (index == 6 ? ']' : ',') + "\n") 
    end
    result
  end

  def save_contribution_map (matrix, file_name = 'random.txt', name = 'random_example')
    File.open(file_name, 'w') do |f|
      f.puts ":#{name}"
      # f.puts matrix.to_s.gsub(' ', '')
      # f.print '['
      # matrix.each_with_index do |row, index|
      #   f.puts row.to_s.gsub(' ', '') + (index == 6 ? ']' : ',')
      # end
      f.print format_matrix_to_output matrix
    end
  end

  # Multiplies 2D matrix by an escalar value
  def map_multiply(matrix, escalar_multiplier = 1)
    matrix.collect do |row|
      row.collect do |num|
        num * escalar_multiplier
      end
    end
  end

  # Time (date-time) for the first Sunday after one year ago today at 12:00pm (noon), at the user's Time Zone
  def calendar_start_date
    right_now = Time.now
    one_year_ago = Time.new(right_now.year - 1, right_now.month, right_now.day, 12, 0, 0, right_now.utc_offset)
    # One week less. It uses one year and 1 week:
    day_in_seconds = 24*60*60
    one_year_ago = one_year_ago - day_in_seconds * 7
    unless one_year_ago.sunday?
      # Weekdays numbering in Ruby: Sunday #=> 0, Saturday #=> 6. So I need to get to the 7th day (zero again)
      weekday_delta = 7 - one_year_ago.wday
      one_year_ago = one_year_ago + day_in_seconds * weekday_delta
    end
    one_year_ago
  end

  # --Specialized Stuff related to the task at hand:

  def get_contributions_svg(user_name)
    contrib_url = @github_url + 'users/' + user_name + '/contributions'
    begin
      contributions_uri = URI(contrib_url)
      page = Net::HTTP.get(contributions_uri) # => String
    rescue Exception => e
      puts "There was a problem fetching data from '#{contrib_url}'"
      puts "#{e}"
      raise 'Halting! ... Bye-bye'
    end
    page.encode('utf-8')
  end

  # Yields a 2D matrix Array of daily counts from the GitHub contributions SVG
  #  Each column is one week
  def get_contributions_calendar(user_name)
    calendar_svg = get_contributions_svg(user_name)
    rect_lines = calendar_svg.scan(/<rect ([^>\n]+)>\n/).flatten
    calendar_by_weekdays = [[]] * 7
    next_value_in = 0
    rect_lines.each do |rect_line|
      num_commits = rect_line.partition('data-count="')[2].partition('"')[0]
      unless num_commits.empty?
        calendar_by_weekdays[next_value_in] += [num_commits.to_i]
        next_value_in = (next_value_in + 1).modulo(7)
      end
    end
    # puts calendar_by_weekdays.size.to_s
    # calendar_by_weekdays.each_with_index {|r,i| puts "Row #{i}: size: #{r.size}"}
    # puts "--Result of get_contributions_calendar(#{user_name}):"
    # puts calendar_by_weekdays.to_s
    # puts '----'
    calendar_by_weekdays
  end

  def calendar_max_value(calendar)
    calendar.flatten.max
  end

  # Multiplier to scale GitHub colors to a commit history
  def scaling_multiplier(max_commits)
    max_commits == 0 ? 1 : (max_commits / 4.0).ceil.to_i
  end

  # 53 or 54 weeks?
  def random_contribution_map (weights = { 0 => 5, 1 => 4, 2 => 3, 3 => 2, 4 => 1 }, weeks = 54)
    file_name = 'test.txt'
    name = 'random_example'
    weighted_array = weights.collect{ |value, weight| [value]*weight }.flatten
    # Like for example: [0,0,0,0,0,1,1,1,1,2,2,2,3,3,4]
    # puts "Weighted array used: #{weighted_array}"
    random_matrix = []
    (1..7).to_a.each do |week_day|
      random_row = []
      (1..weeks).to_a.each do |week_number|
        random_row << weighted_array.sample
      end
      random_matrix << random_row
    end
    # puts '*RANDOM MATRIX:********'
    # puts random_matrix.to_s
    # puts '*********'
    random_matrix
  end

  # Sets the contribution calendar to use only numbers 0..4
  def normalize_calendar(contributions_calendar)
    max_value = calendar_max_value(contributions_calendar)
    scaling_value = scaling_multiplier(max_value.to_f).to_f
    contributions_calendar.collect do |row|
      row.collect do |n|
        (n/scaling_value).ceil.to_i
      end
    end
  end

  # Next date, given a Time object
  def day_plus_offset(datetime_obj, days_offset)
    day_in_seconds = 24*60*60
    datetime_obj + days_offset*day_in_seconds
  end

  def commit_command(commit_date)
    iso_date = commit_date.strftime '%FT%T'
    "GIT_AUTHOR_DATE=#{iso_date} GIT_COMMITTER_DATE=#{iso_date} "\
    "git commit --allow-empty -m \"contrib_map\" > /dev/null\n"
  end

  def contribution_shell_script(image_map, start_date, username, repo, git_url)
    # puts '1. image_map matrix:'
    # puts '********'
    # puts format_matrix_to_output(image_map)
    # puts '********'

    commit_lines = []
    # puts '***Dates*****'
    # puts "Start date: #{start_date}"
    image_map.each_with_index do |weekday_row, index|
      commit_date = day_plus_offset(start_date, index)
      weekday_row.each do |value|
        # puts "Value, commit_date: [#{value}, #{commit_date}]"
        if value > 0
          commit_line = commit_command(commit_date)
          (1..value).to_a.each do |num|
            commit_lines << commit_line
          end
          # puts 'Commits added!'
        end
        commit_date = day_plus_offset(commit_date, 7)  # Next week, same week day
        # puts "Next commit_date: [#{commit_date}]"
      end
    end
    # puts '********'

    # Returned value (shell script):

    "#!/bin/bash\n"\
    "\n"\
    "REPO=#{repo}\n"\
    "git init $REPO\n"\
    "cd $REPO\n"\
    "touch README.md\n"\
    "git add README.md\n"\
    "touch contrib_map\n"\
    "git add contrib_map\n"\
    "#{commit_lines.join}\n"\
    "git remote add origin #{git_url}:#{username}/$REPO.git\n"\
    "git pull\n"\
    "git push -u origin master\n"
  end

end


# Possible modes:
#
#  All of them will output a shell scripts (.sh), and some an optional output_map (text file).
#
#   1. random_map output_script output_map
#      [ WORK IN PROGRESS ]
#      Create a random map.
#   2. copy_user user_name output_script output_map_file
#      [ WORK IN PROGRESS ]
#      Mime existing user'map
#      And create the script + map matrix
#   3. existing_map map_file output_script
#      [ NOT IMPLEMENTED YET ]
#      Use predefined existing map(s)
#

contrib_mapper = ContribMap.new(username: 'carloscd', repo_to_change: 'contrib_mapper')
puts '--RANDOM-------------------------------------------------------------------------'
contrib_mapper.random_map output_file: 'random.sh', map_file: 'random.txt'
puts '---------------------------------------------------------------------------------'

puts '--COPY USER----------------------------------------------------------------------'
contrib_mapper.copy_user user_to_copy: 'tenderlove', output_file: 'tenderlove.sh', map_file: 'tenderlove.txt'
puts '---------------------------------------------------------------------------------'

# contrib_mapper.existing_map map_file: 'hello.txt', output_file: 'hello.sh'
