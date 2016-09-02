#!/usr/bin/env ruby

#
# Copyright (c) 2016 Carlos A. Carro Duplá (@ccarrodupla)
# released under The MIT license (MIT) http://opensource.org/licenses/MIT
#

class ContribMap

  GITHUB_URL = 'https://github.com/'
  DEFAULT_OPTIONS = {
                      github_url:     "Enter GitHub URL (leave blank to use #{GITHUB_URL})",
                      username:       'Your GitHub user name',
                      repo_to_change: 'Repository to be used to send changes',
                      copy_user:      'Mime the map of the user'
                    }

  def perform(options = { github_url: GITHUB_URL, username: 'carloscd', repo_to_change: 'contrib_mapper', copy_user: 'tenderlove' })
    # Set the options:
    ContribMap::DEFAULT_OPTIONS.each do |data_to_collect, message|
      # puts "#{data_to_collect}: '#{message}'"
      if options[data_to_collect]
        instance_variable_set "@#{data_to_collect}".to_sym, options[data_to_collect]
      else
        puts message + ': '
      #   entered_value = gets.chomp
      #   instance_variable_set data_to_collect (ghe.blank? ? options[data_to_collect] : entered_value)
      end
    end
    puts 'Got: '
    instance_variables.each do |data_collected|
      puts " #{data_collected}: [#{instance_variable_get data_collected}]"
    end
    puts '---'
    ContribMap::DEFAULT_OPTIONS.keys.each do |data_collected|
      puts " @#{data_collected}: [#{instance_variable_get "@#{data_collected}".to_sym}]"
    end
  end

end

ContribMap.new.perform
