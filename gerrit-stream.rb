#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'optparse'
require "highline/system_extensions"
include HighLine::SystemExtensions

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


cmd = "ssh #{options[:username]}@review.openstack.org -p 29418 gerrit stream-events"

ENV['GIT_ASKPASS']='echo'
Dir.chdir("nova")
`git checkout master 2> /dev/null`
puts `git pull`

puts cmd 
#data = `#{cmd}`

IO.popen("#{cmd}") { |p| p.each{ |line| 
    blob = JSON.parse(line)
    #puts JSON.pretty_generate(blob)
    if blob['change']!=nil &&  blob['change']['url']
      url = blob['change']['url']
    else
      url = blob['url']
    end
    if blob['type']=='ref-updated'
      if blob['submitter']!=nil
        puts "type: #{blob['type']}\tsubmitter #{blob['submitter']['name']}"
      else 
        puts "type: #{blob['type']}"
      end
      puts JSON.pretty_generate(blob)
      next
    end
    if blob['type']=='patchset-created' && 
       blob['change']['project']=='openstack/nova' && 
       blob['change']['branch']=='master'
      puts "type: #{blob['type']}"
      puts "#{url}\n\tproject: #{blob['change']['project']}\n\ttopic: "\
          "#{blob['change']['topic']}\n\tbranch: #{blob['change']['branch']}\n"\
          "\tsubject: #{blob['change']['subject']}"
      puts "run tests y/n?"
      yn = get_character
      if yn==121
          puts "running unit tests ..."
          `git fetch https://@review.openstack.org/p/openstack/nova #{blob['ref']}   &>/dev/null  && git checkout FETCH_HEAD &> /dev/null`
          system("./run_tests.sh","-x")
          puts "#{url}"
          puts "tests done.  Press any key to continue ..."
          `git checkout master 2> /dev/null`
          cont = get_character
      else
          puts "no testing.  listining..."
      end
      #puts JSON.pretty_generate(blob)
    elsif blob['type']=='comment-added' && blob['change']['project']=='openstack/nova'
       puts "type: #{blob['type']}"
       puts "#{url}\n\tproject: #{blob['change']['project']}\n"\
            "\ttopic: #{blob['change']['topic']}\n"\
            "\tbranch: #{blob['change']['branch']}"
       puts "\tauthor: #{blob['author']['name']}\tusername: #{blob['author']['username']}"
       puts "\ttopic: #{blob['change']['topic']}\tsubject: #{blob['change']['subject']}"
       #puts JSON.pretty_generate(blob['approvals']) #TODO TESTING HERE
       if blob['approvals']!=nil and blob['approvals'][0]!=nil
         puts "\treview: #{blob['approvals'][0]['value']}" #TODO TESTING HERE
       end
       puts "\tcomment: \n\t\t#{blob['comment']}"
    elsif blob['type']=='change-merged' && 
          blob['change']['project']=='openstack/nova'
      puts `git pull `
    else
      puts "type: #{blob['type']}"
      puts "#{url}\n\tproject: #{blob['change']['project']}\n\ttopic: "\
           "#{blob['change']['topic']}\n\tbranch: #{blob['change']['branch']}\n"\
           "\tsubject: #{blob['change']['subject']}"
    end
    puts ""
}}

