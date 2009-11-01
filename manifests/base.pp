class mediawiki::base {
  package{'mediawiki':
    ensure => present,
  }

  include rubygems::highline
  include ruby::mysql

  file{'/opt/bin/mediawiki_dbupdate.config.rb':
    source => [ "puppet://$server/files/mediawiki/updatescript/${fqdn}/mediawiki_dbupdate.config.rb",
                "puppet://$server/files/mediawiki/updatescript/mediawiki_dbupdate.config.rb",
                "puppet://$server/modules/mediawiki/updatescript/mediawiki_dbupdate.config.rb" ],
    require => [ Package['ruby-mysql'], Package['rubygem-highline'] ],
    owner => root, group => 0, mode => 0600;
  }
  file{'/opt/bin/mediawiki_dbupdate.rb':
    source => "puppet://$server/modules/mediawiki/updatescript/mediawiki_dbupdate.rb",
    require => File['/opt/bin/mediawiki_dbupdate.config.rb'],
    owner => root, group => 0, mode => 0700;
  }
}
