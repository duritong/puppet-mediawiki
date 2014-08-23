#!/usr/bin/ruby -w

require 'ftools'
require 'fileutils'

load File.dirname(__FILE__) + "/mediawiki_dbupdate.config.rb"

def update_php(dir)
  old_dir = Dir.getwd
  Dir.chdir(dir)
  stat = File.stat(dir)
  sudo(stat.uid, stat.gid) do
    File.symlink("#{MEDIAWIKI_SOURCE}/maintenance","#{dir}/maintenance") unless File.exists?("#{dir}/maintenance")
    [ "php maintenance/update.php --quick --conf #{dir}/LocalSettings.php",
      "find #{File.join(dir,'cache')} -name '*.html' -type f -delete" ].each do |cmd|
      run(cmd)
    end
    FileUtils.remove_entry_secure("#{dir}/maintenance", true)
  end
  Dir.chdir(old_dir)
end

def run(cmd)
  result = `#{cmd}`.split("\n")
  if $?.to_i > 0
    output = result
  elsif !result.empty? && result.size > 2
    output = result[(result.length-3)..(result.length-1)]
  else
    output = result
  end
  output.each{|l| puts "> #{l}"}
end

def wikis
  `ls #{VHOSTS_BASE}/*/www/LocalSettings.php`.collect{|f| File.dirname(f)}
end

def sudo(uid,gid,&blk)
  # fork off shell command to irrevocably drop all root privileges
  pid = fork do
    Process::Sys.setregid(gid,gid)
    security_fail('could not drp privileges') unless Process::Sys.getgid == gid
    security_fail('could not drop privileges') unless Process::Sys.getegid == gid
    Process::Sys.setreuid(uid,uid)
    security_fail('could not drop privileges') unless Process::Sys.getuid == uid
    security_fail('could not drop privileges') unless Process::Sys.geteuid == uid
    yield blk
  end
  Process.wait pid
end

def security_fail(msg)
  puts "Error: #{msg}"
  puts "Aborting..."
  exit 1
end

puts "updating git..."
Dir.chdir(MEDIAWIKI_SOURCE)
run('git pull')
puts "done"

wikis.each do |dir|
  puts "processing wiki: #{dir}"
  update_php(dir)
  puts "done."
end
puts "All done!"

