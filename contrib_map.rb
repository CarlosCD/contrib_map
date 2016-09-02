#!/usr/bin/env ruby

#
# Copyright (c) 2016 Carlos A. Carro Duplá (@ccarrodupla)
# released under The MIT license (MIT) http://opensource.org/licenses/MIT
#

class ContribMap

  require 'net/http'
  # require 'uri'

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
    my_max_daily_commits = my_contributions_calendar.max
    puts "Your maximum number of daily commits is: #{my_max_daily_commits}"
    faking_multiplier = scaling_multiplier(my_max_daily_commits)

    if present?(@copy_user)
      their_contributions_calendar = get_contributions_calendar(@copy_user)
      their_max_daily_commits = their_contributions_calendar.max
      puts "Their maximum number of daily commits is: #{their_max_daily_commits}"
      # Calendar for values 0..4:
      their_contributions_calendar = normalize_calendar(their_contributions_calendar)
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

  # Yield and Array of daily counts from the GitHub contributions SVG
  def get_contributions_calendar(user_name)
    calendar_svg = get_contributions_svg(user_name)
    calendar_svg.scan(/<rect ([^>\n]+)>\n/).flatten.collect do |rect_line|
      # puts "line: [#{rect_line}]"
      # puts
      num_commits = rect_line.partition('data-count="')[2].partition('"')[0]
      num_commits.empty? ? nil : num_commits.to_i
    end.compact
  end

  # Multiplier to scale GitHub colors to a commit history
  def scaling_multiplier(max_commits)
    max_commits == 0 ? 1 : (max_commits / 4.0).ceil.to_i
  end

  # Sets the contribution calendar to use only numbers 0..4
  def normalize_calendar(contributions_calendar)
    max_value = contributions_calendar.max.to_f
    scaling_value = scaling_multiplier(max_value).to_f
    contributions_calendar.collect{|n| (n/scaling_value).ceil.to_i}
  end

end

ContribMap.new.perform
