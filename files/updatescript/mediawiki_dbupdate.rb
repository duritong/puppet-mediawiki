#!/usr/bin/ruby -w

require 'fileutils'

load File.dirname(__FILE__) + "/mediawiki_dbupdate.config.rb"

def update_php(dir)
  old_dir = Dir.getwd
  Dir.chdir(dir)
  stat = File.stat(dir)
  sudo(stat.uid, stat.gid) do
    File.symlink("#{MEDIAWIKI_SOURCE}/maintenance","#{dir}/maintenance") unless File.exists?("#{dir}/maintenance")
    # make sure we do not have a tampered update_command before running it
    if File.exists?(update_cmd_file = File.expand_path("#{dir}/../data/php_update_command")) && ((s=File.stat(update_cmd_file)).uid == 0) && (sprintf("%o",s.mode) == "100644")
      run(File.read(update_cmd_file))
    else
      run("php #{dir}/maintenance/update.php --quick --conf #{dir}/LocalSettings.php")
    end
    FileUtils.remove_entry_secure("#{dir}/maintenance", true)
  end
  # history folder is owned by the run user
  d = File.join(dir,'cache','history')
  if File.directory?(d)
    stat = File.stat(d)
    sudo(stat.uid, stat.gid) do
      run("find #{File.join(dir,'cache')} -name '*.html' -type f -delete")
    end
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
  `ls #{VHOSTS_BASE}/*/www/LocalSettings.php`.collect{|f|
    File.dirname(f)
  }.select{|f| File.symlink?(File.join(f,'index.php')) }
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
  puts 'Aborting...'
  exit 1
end

if File.directory?(File.join(MEDIAWIKI_SOURCE,'.git'))
  puts 'updating git...'
  old_dir = Dir.getwd
  Dir.chdir(MEDIAWIKI_SOURCE)
  run('git pull && git submodule update --init')
  puts 'done'
  Dir.chdir(old_dir)
end

wikis.each do |dir|
  puts "processing wiki: #{dir}"
  update_php(dir)
  puts 'done.'
end
puts 'All done!'

