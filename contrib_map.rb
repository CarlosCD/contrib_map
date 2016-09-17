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
    puts 'my_contributions_calendar:'
    # puts '*********'
    puts my_contributions_calendar.to_s
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
                  map_file:    'Map tet file to be generated'
                }
    set_data(true, defaults.keys, defaults, questions, [], received_options)
    # Here I should have the instance variables:
    #  @github_url, @repo_to_change, @username
    #  @output_file, @map_file
    save_contribution_map random_contribution_map, @map_file
    # Pending to generate the script.
  end

  def copy_user(received_options = {})
    defaults = { user_to_copy: 'tenderlove', output_file: 'tenderlove.sh' }
    questions = {
                  copy_user:   'Use the shape of the map of this user',
                  output_file: 'The output shell script'
                }
    optionals = [ :map_file ]
    set_data(true, defaults.keys, defaults, questions, optionals, received_options)
    # Here I should have the instance variables:
    #  @github_url, @repo_to_change, @username
    #  @user_to_copy, @output_file
    #  And optional: @map_file
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

  def save_contribution_map (matrix, file_name = 'random.txt', name = 'random_example')
    File.open(file_name, 'w') do |f|
      f.puts ":#{name}"
      # f.puts matrix.to_s.gsub(' ', '')
      f.print '['
      matrix.each_with_index do |row, index|
        f.puts row.to_s.gsub(' ', '') + (index == 6 ? ']' : ',')
      end
    end
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

  def random_contribution_map (weights = { 0 => 5, 1 => 4, 2 => 3, 3 => 2, 4 => 1 }, weeks = 53)
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

contrib_mapper.random_map output_file: 'random.sh', map_file: 'random.txt'

# contrib_mapper.copy_user user_to_copy: 'tenderlove', output_file: 'tenderlove.sh', map_file: 'tenderlove.txt'
# contrib_mapper.existing_map map_file: 'hello.txt', output_file: 'hello.sh'
