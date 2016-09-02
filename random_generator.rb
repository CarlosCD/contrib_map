#!/usr/bin/env ruby

class Templater
  WEIGHTS = {
              0 => 5,
              1 => 4,
              2 => 3,
              3 => 2,
              4 => 1
            }
  def initialize(weeks = 53, file_name = 'test.txt', name = 'random_example')
    weighted_array = WEIGHTS.collect{ |value, weight| [value.to_s]*weight }.flatten
    puts "Weighted array used: #{weighted_array}"
    File.open(file_name, 'w') do |f|
      f.puts ":#{name}"
      (1..7).to_a.each do |week_day|
        random_sequence = '['
        random_sequence << '[' if week_day == 1
        if weeks > 1
          (1..(weeks-1)).to_a.each do |week_num|
            random_sequence << "#{weighted_array.sample.to_s},"
          end
        end
        random_sequence << "#{weighted_array.sample.to_s}]"
        random_sequence <<  ((week_day == 7) ? ']' : ',')
        f.puts random_sequence
      end
    end
  end
end

Templater.new
