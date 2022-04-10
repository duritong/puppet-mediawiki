#!/usr/bin/ruby -w

require 'fileutils'

VHOSTS_BASE = '/var/www/vhosts'

def update_php(dir)
  old_dir = Dir.getwd
  Dir.chdir(dir)
  stat = File.stat(dir)
  ran = false
  sudo(stat.uid, stat.gid) do
    if (`git fetch -q && git log --oneline HEAD..@{u} | wc -l`.split("\n").first.to_i != 0) || (ENV['FORCE_UPGRADE'].to_i == 1)
      run('git pull -q && git submodule -q sync && git submodule -q update --init')
      # make sure we do not have a tampered update_command before running it
      if File.exists?(update_cmd_file = File.expand_path("#{dir}/../data/php_update_command")) && ((s=File.stat(update_cmd_file)).uid == 0) && (sprintf("%o",s.mode) == "100644")
        run("MW_INSTALL_PATH=#{dir} #{File.read(update_cmd_file)}")
      else
        run("MW_INSTALL_PATH=#{dir} php #{dir}/maintenance/update.php --quick --conf #{dir}/LocalSettings.php")
      end
      ran = true
    else
      puts "No upgrade present and FORCE_UPGRADE not set to 1, skipping..."
    end
  end

  if ran
    # history folder is owned by the run user
    d = File.join(dir,'cache','history')
    if File.directory?(d)
      stat = File.stat(d)
      sudo(stat.uid, stat.gid) do
        run("find #{File.join(dir,'cache')} -name '*.html' -type f -delete")
      end
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
  Dir["/var/www/vhosts/#{wiki_sel}/www/LocalSettings.php"].map{|f| File.dirname(f) }.select{|d| File.directory?(File.join(d,'.git')) }
end

def wiki_sel
  if ARGV.length == 0
    '*'
  else
    "{#{ARGV.join(',')}}"
  end
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

wikis.each do |dir|
  puts "processing wiki: #{File.basename(File.dirname(dir))}"
  update_php(dir)
  puts 'done.'
end
puts 'All done!'

