#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'optparse'
require 'pp'
require 'pty'

$options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gerrit-monitor.rb -u username [options]"
  opts.on("-u username","--username username", "gerrit username - required") do |u|
    $options[:username] = u
  end
  opts.on("-n","--notify", "use notifications") do |n|
    $options[:notify] = n
  end
  opts.on("-H hostname","--host hostname", "gerrit host") do |host|
    $options[:host] = host
  end
  opts.on_tail("-h","--help", "Show this messege") do
    puts opts
    exit
  end
end.parse!

unless $options[:username]
  $stderr.puts "Error: --username is required"
  exit
end

# default host - review.openstack.org
unless $options[:host]
  $options[:host] = "review.openstack.org"
end

puts $options[:host]


cmd = "ssh #{$options[:username]}@#{$options[:host]} -p 29418 gerrit stream-events"

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
            highlights['comment'] = blob['comment']
            if blob['approvals']
              highlights['approval-values'] = blob['approvals'].map{|x| x['value']}
            end
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

class Notify
  def initialize()
    if RUBY_PLATFORM.include?('linux')
      @@type = :linux
    else
      @@type = :growl
    end
  end

  def notify(highlights)
    if @@type == :growl
     growl(highlights)
    elsif @@type == :linux
     linux(highlights)
    end 
  end

  def linux(highlights)
    hl = highlights.clone
    project = hl.delete('project')
    str = ""
    hl.each{|k,v| str+="#{k}: #{v}\n"}
    `notify-send #{project} "#{str}" `

  end

  def growl(highlights)
    hl = highlights.clone
    project = hl.delete('project')
    str = ""
    hl.each{|k,v| str+="#{k}: #{v}\n"}
    `echo "#{str}" | growlnotify  #{project} -d 42 --image #{$options[:host]}.png`
  end
end


Thread.new do
  while true
    c = STDIN.getc()
    system('clear')
  end
end

notify = Notify.new()
PTY.spawn("#{cmd}") { |r,w,pid| r.each{ |line|
    blob = JSON.parse(line)
    puts  "---------"
    puts Time.now.getlocal.strftime("Time: %T")
    highlights = extract(blob)
    pp highlights
    if $options[:notify] and highlights['project']=='openstack/nova'
        notify.notify(highlights)
    end
}}
