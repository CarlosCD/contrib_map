#!/usr/bin/env ruby

#
# Copyright (c) 2016 Carlos A. Carro Duplá (@ccarrodupla)
# released under The MIT license (MIT) http://opensource.org/licenses/MIT
#

class ContribMap

  require 'net/http'

  DEFAULT_OPTIONS = {
                      github_url:     'https://github.com/',
                      repo_to_change: 'contrib_mapper'
                    }
  OPTIONS_AND_QUESTIONS = {
                            github_url:     "Enter GitHub URL#{" (leave blank to use #{DEFAULT_OPTIONS[:github_url]})" if DEFAULT_OPTIONS[:github_url]}",
                            username:       'Your GitHub user name',
                            repo_to_change: "Repository to be used to send changes#{" (leave blank to use #{DEFAULT_OPTIONS[:repo_to_change]})" if DEFAULT_OPTIONS[:repo_to_change]}",
                            copy_user:      'Use the shape of the map of this user'
                          }

  # Takes a Hash of options, just to avoid the annoying questioning to set it up for the same values every time.
  #  Change the default options if you wish
  #  Example:
  def perform(options = { github_url: 'https://github.com/', username: 'carloscd', repo_to_change: 'contrib_mapper', copy_user: 'tenderlove' })
  # def perform(options = {})
    # Set the options:
    ContribMap::OPTIONS_AND_QUESTIONS.each do |data_to_collect, message|
      # puts "#{data_to_collect}: '#{message}'"
      if options[data_to_collect]
        instance_variable_set "@#{data_to_collect}".to_sym, options[data_to_collect]
      else
        puts message + ': '
        entered_value = gets.chomp
        instance_variable_set "@#{data_to_collect}".to_sym, (entered_value.empty? ? DEFAULT_OPTIONS[data_to_collect] : entered_value)
      end
    end
    puts 'Got: '
    ContribMap::OPTIONS_AND_QUESTIONS.keys.each do |data_collected|
      puts " - #{snakecase_prettifier data_collected}: [#{instance_variable_get "@#{data_collected}".to_sym}]"
    end
    # puts '---'
    # instance_variables.each do |data_collected|
    #   puts " #{data_collected}: [#{instance_variable_get data_collected}]"
    # end
    # Required data:
    unless all_string_with_values?(@github_url, @username, @repo_to_change)
      puts 'Missing information. Either the GitHub URL, the username, or ythe repo to change are missing'
      return
    end

    my_contributions_calendar = get_contributions_calendar(@username)
    my_max_daily_commits = calendar_max_value my_contributions_calendar
    puts "Your maximum number of daily commits is: #{my_max_daily_commits}"
    faking_multiplier = scaling_multiplier(my_max_daily_commits)

    if present?(@copy_user)
      their_contributions_calendar = get_contributions_calendar(@copy_user)
      their_max_daily_commits = calendar_max_value their_contributions_calendar
      puts "The maximum number of daily commits of #{@copy_user} is: #{their_max_daily_commits}"
      puts "We will try to match #{@copy_user}'s repository map"
      # Calendar for values 0..4:
      their_contributions_calendar = normalize_calendar(their_contributions_calendar)

      start_date = calendar_start_date

      git_url = 'git@github.com'

      shell_script = contribution_shell_script(their_contributions_calendar, calendar_start_date, @username, @repo_to_change, git_url, faking_multiplier, 0)
      puts 'Script:'
      puts '*********'
      puts shell_script
      puts '*********'
    else
      puts 'No user to copy. Bothing to do!'
    end
  end

  private

  # --General utility methods:
  
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

  # Time (date-time) for the first Sunday after one year ago today at 12:00pm (noon), at the user's Time Zone
  def calendar_start_date
    right_now = Time.now
    one_year_ago = Time.new(right_now.year - 1, right_now.month, right_now.day, 12, 0, 0, right_now.utc_offset)
    unless one_year_ago.sunday?
      day_in_seconds = 24*60*60
      # Weekdays numbering in Ruby: Sunday #=> 0, Saturday #=> 6. So I need to get to the 7th day (zero again)
      weekday_delta = 7 - one_year_ago.wday
      one_year_ago = one_year_ago + day_in_seconds * weekday_delta
    end
    one_year_ago
  end

  # Multiplies 2D matrix by an escalar value
  def map_multiply(matrix, escalar_multiplier = 1)
    matrix.collect do |row|
      row.collect do |num|
        num * escalar_multiplier
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
    # puts calendar_by_weekdays.to_s
    calendar_by_weekdays
  end

  # Multiplier to scale GitHub colors to a commit history
  def scaling_multiplier(max_commits)
    max_commits == 0 ? 1 : (max_commits / 4.0).ceil.to_i
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

  def calendar_max_value(calendar)
    calendar.flatten.max
  end

  # Next date, given a Time object
  def next_date(datetime_obj, offset_in_weeks = 0)
    day_in_seconds = 24*60*60
    datetime_obj + (offset_in_weeks * 7 * day_in_seconds)
  end

  def commit_command(commit_date)
    iso_date = commit_date.strftime '%FT%T'
    "GIT_AUTHOR_DATE=#{iso_date} GIT_COMMITTER_DATE=#{iso_date} "\
    "git commit --allow-empty -m \"contrib_map\" > /dev/null\n"
  end

  def contribution_shell_script(image_map, start_date, username, repo, git_url, multiplier = 1, weeks_offset = 0)
    commit_lines = []
    # next_date = start_date
    # image_map.each do |row|
    #   row.each do |value|
    #     (0..value*multiplier).each do
    #       commit_lines << commit_command(next_date)
    #       next_date = next_date(start_date, weeks_offset)
    #     end
    #   end
    # end

    "#!/bin/bash\n"\
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

ContribMap.new.perform
