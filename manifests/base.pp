class mediawiki::base {
  package{'mediawiki':
    ensure => present,
  }

  file{'/opt/bin/mediawiki_dbupgrade.rb':
    source => [ "puppet://$server/files/mediawiki/upgradescript/mediawiki_dbupgrade.rb",
                "puppet://$server/mediawiki/upgradescript/mediawiki_dbupgrade.rb" ],
    owner => root, group => 0, mode => 0700;
  }
}
