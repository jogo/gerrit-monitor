#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gerrit.rb -u username [options]"
  opts.on("-u username","--username username", "gerrit username - required") do |u|
    options[:username] = u
  end
end.parse!

unless options[:username]
  $stderr.puts "Error: --username is required"
  exit
end

def get_key() 
      begin
        STDIN.flush
        system("stty raw -echo")
        char = STDIN.getc
      ensure
        system("stty -raw echo")
      end
      puts char
      return char
end

cmd = "ssh #{options[:username]}@review.openstack.org -p 29418 gerrit stream-events"

puts cmd 

IO.popen("#{cmd}") { |p| p.each{ |line| 
    blob = JSON.parse(line)
    if blob['change'] and blob['change']['project']=='openstack/nova'
        puts JSON.pretty_generate(blob)
    elsif blob['type']=="comment-added"  
        puts "type: #{blob['type']}, project: #{blob['change']['project']}, author: #{blob['author']['name']}, topic: #{blob['change']['topic']}"
    elsif  blob['type']=="change-merged"
        puts "type: #{blob['type']}, project: #{blob['change']['project']}, submitter: #{blob['submitter']['name']}, topic: #{blob['change']['topic']}"
    elsif blob['type']=="change-abandoned"
        puts "type: #{blob['type']}, project: #{blob['change']['project']}, abandoner: #{blob['abandoner']['name']}, topic: #{blob['change']['topic']}"
    elsif blob['type']=="ref-updated"
        puts "type: #{blob['type']}, project: #{blob['refUpdate']['project']}"
    elsif blob['type']=="patchset-created"
        puts "type: #{blob['type']}, project: #{blob['change']['project']}, uploader: #{blob['uploader']['name']}, topic: #{blob['change']['topic']}"
    else
        puts "type: #{blob['type']}"
        puts "type: #{blob['type']}, project: #{blob['change']['project']}, topic: #{blob['change']['topic']}"
    end
}}
