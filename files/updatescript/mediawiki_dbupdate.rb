#!/usr/bin/ruby -w

MEDIAWIKI_SOURCE = '/var/www/mediawiki'
VHOSTS_BASE = '/var/www/vhosts'

#########################################

require 'rubygems'
require 'highline/import'
require 'ftools'
require 'fileutils'
require 'mysql'

$perms = 'CREATE,ALTER,INDEX,DROP,CREATE TEMPORARY TABLES,CREATE VIEW,SHOW VIEW,CREATE ROUTINE,ALTER ROUTINE,EXECUTE'

def match_vardecl(txt, var)
  m = txt.match(/\$#{var} *= *"(.*)"/)
  return m ? m[1] : nil  
end

def get_db_info(dir)
  txt = File.read(File.join(dir, 'LocalSettings.php'))

  dbname, dbuser = nil, nil
  dbname ||= match_vardecl(txt, "wgDBname")
  dbuser ||= match_vardecl(txt, "wgDBuser")

  return [dbname, dbuser]
end

def grant(dbh, dbname, dbuser)
  dbh.query("GRANT #{dbh.quote($perms)} ON `#{dbh.quote(dbname)}`.* TO '#{dbh.quote(dbuser)}'@'127.0.0.1';")
end

def revoke(dbh, dbname, dbuser)
  dbh.query("REVOKE #{dbh.quote($perms)} ON `#{dbh.quote(dbname)}`.* FROM '#{dbh.quote(dbuser)}'@'127.0.0.1';")
end

def update_php(dir)
  old_dir = Dir.getwd
  Dir.chdir(dir)
  File.move("#{dir}/maintenance #{dir}/maintenance_old")
  FileUtils.cp_r("#{MEDIAWIKI_SOURCE}/maintenance #{dir}/maintenance")
  result = `php maintenance/update.php --quick`.split("\n")
  result[(result.length-3)..(result.length-1)].each{|l| puts "> #{l}"} 
  FileUtils.remove_entry_secure("#{dir}/maintenance", true)
  File.move("#{dir}/maintenance_old #{dir}/maintenance")
  Dir.chdir(old_dir)
end

def dbupdate(dir, dbh)
  dbname, dbuser = get_db_info(dir)
  grant(dbh, dbname, dbuser)
  update_php(dir)  
  revoke(dbh, dbname, dbuser)
end

def connect_db()
  user = ask("Enter db user name with global grant privileges: ")
  passwd = ask("Enter your password:  ") { |q| q.echo = "x" }
  dbh = Mysql.real_connect("dbhost", user, passwd)
  puts "Server version: " + dbh.get_server_info
  return dbh
end

def close_db(dbh)
  dbh.close if dbh
end

def get_wikis()
  `ls #{VHOSTS_BASE}/*/www/LocalSettings.php`.collect{|f| File.dirname(f)} 
end

begin
  dbh = connect_db()  

  get_wikis().each do |dir|
    puts "processing wiki: #{dir}"
    dbupdate(dir,dbh)
  end

  puts "done."
rescue Mysql::Error => e
  puts "Error code: #{e.errno}"
  puts "Error message: #{e.error}"
  puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
ensure
  close_db(dbh)
end
