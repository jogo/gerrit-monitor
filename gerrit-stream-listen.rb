#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'optparse'
require 'pp'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gerrit.rb -u username [options]"
  opts.on("-u username","--username username", "gerrit username - required") do |u|
    options[:username] = u
  end
  opts.on("-g","--growl", "use growl notifications") do |g|
    options[:growl] = g
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


# extract information we want
def extract(blob)
    highlights= {}
    highlights['type'] = blob['type']
    if blob['type']=="ref-updated"
        highlights['project'] = blob['refUpdate']['project']
    else
        highlights['project'] = blob['change']['project']
        highlights['subject'] = blob['change']['subject']
        highlights['url'] = blob['change']['url']
        if blob['type']=="comment-added"  
            highlights['author'] = blob['author']['name']
        elsif  blob['type']=="change-merged"
            highlights['submitter'] = blob['submitter']['name']
        elsif blob['type']=="change-abandoned"
            highlights['abandoner'] = blob['abandoner']['name']
        elsif blob['type']=="patchset-created"
            highlights['uploader'] = blob['uploader']['name']
        end
    end

    return highlights 
end

def growl(highlights)
    hl = highlights.clone
    project = hl.delete('project')
    str = "" 
    hl.each{|k,v| str+="#{k}: #{v}\n"}
    `echo "#{str}" | growlnotify  #{project} -d 42 --image openstack.png`
end

IO.popen("#{cmd}") { |p| p.each{ |line| 
    blob = JSON.parse(line)
    if blob['change'] and blob['change']['project']=='openstack/nova'
        puts JSON.pretty_generate(blob)
    end
    highlights = extract(blob) 
    pp highlights
    puts  "---------"
    if options[:growl]
        growl(highlights)
    end
}}
