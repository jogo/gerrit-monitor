#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'optparse'

status  =  'open'
project =  'nova'
branch  =  'master'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gerrit.rb -u username [options]"
  opts.on("-u username","--username username", "gerrit username - required") do |u|
    options[:username] = u
  end
  opts.on("-s","--start", "start URL") do |s|
    options[:url] = s
  end
end.parse!

unless options[:username]
  $stderr.puts "Error: --username is required"
  exit
end

cmd = "ssh #{options[:username]}@review.openstack.org -p 29418 gerrit query \"status: #{status} "\
      "project: openstack/#{project} branch: #{branch} "\
      "--current-patch-set --format JSON\""


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



#TODO add support for ending at specific URL, and print first URL run at end of program, to use for next time.
#TODO Add in `ssh review gerrit stream-events` support

#TODO cleanup args 
ENV['GIT_ASKPASS']='echo'
Dir.chdir("nova")
`git checkout master 2> /dev/null`
puts `git pull`



puts cmd 
data = `#{cmd}`
#puts data 
data.each_line(){|line|
  #puts line
  blob = JSON.parse(line)
  if blob.has_key? 'project' and  blob.has_key? 'url' 
    test = true
    if options[:url]!= nil and options[:url]!=blob['url'] 
        test = false
        next
    elsif options[:url]!=nil and options[:url]==blob['url']
        options[:url]=nil
    end
    blob['currentPatchSet']['approvals'] ||= [] #make sure not nil
    # find lowest review.
    posneg = 4 #higher then any possible value
    blob['currentPatchSet']['approvals'].each{|x| 
      val =  x['value'].to_i
      if val<0 or val>1 
        #if already has negative review skip
        test = false 
        next
      else
        posneg = posneg < val ? posneg :  val 
      end
    }
    if test 
      puts "subject: #{blob['subject']}  \n\t url: #{blob['url']}"
      `git fetch https://review.openstack.org/p/openstack/nova #{blob['currentPatchSet']['ref']}   2>/dev/null  && git checkout FETCH_HEAD 2> /dev/null`
      puts "\trunning pep8 tests..."
      pep8 = `./run_tests.sh -p`
      if pep8.size()>20 
        puts "\t#{pep8}"
        if blob['currentPatchSet']['approvals'].size()>0
          puts "subject: #{blob['subject']}  \n\t# reviews: #{blob['currentPatchSet']['approvals'].size()} worst review: #{posneg}"
        else
          puts "subject: #{blob['subject']}  \n\t# reviews: 0"
        end
        puts "\t#{blob['url']}"

        puts "\tRun unit tests? y/n"
        yn = get_key()
        if yn=='y'
          puts "running unit tests ..."
          system("./run_tests.sh","-x")
          puts "tests DONE, press any key to continue ..."
          get_key()
        end
      else
        puts "\tpep8 test PASSED"
      end
      `git checkout master 2> /dev/null`
    end
  end
}

puts "run GerritStream for realtime monitoring of Gerrit"
