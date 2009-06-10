class mediawiki::base {
  package{'mediawiki':
    ensure => present,
  }

  file{'/opt/bin/mediawiki_dbupdate.rb':
    source => [ "puppet://$server/files/mediawiki/updatescript/mediawiki_dbupdate.rb",
                "puppet://$server/mediawiki/updatescript/mediawiki_dbupdate.rb" ],
    owner => root, group => 0, mode => 0700;
  }
}
