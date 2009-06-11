class mediawiki::base {
  package{'mediawiki':
    ensure => present,
  }

  include rubygems::highline
  include ruby::mysql

  file{'/opt/bin/mediawiki_dbupdate.rb':
    source => [ "puppet://$server/files/mediawiki/updatescript/mediawiki_dbupdate.rb",
                "puppet://$server/mediawiki/updatescript/mediawiki_dbupdate.rb" ],
    require => [ Package['ruby-mysql'], Package['rubygems-highline'] ],
    owner => root, group => 0, mode => 0700;
  }
}
