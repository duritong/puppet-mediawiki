class mediawiki::base {
  package{'mediawiki':
    ensure => present,
  }

  include rubygems::highline
  include ruby::mysql

  file{'/opt/bin/mediawiki_dbupdate.config.rb':
    source => [ "puppet:///modules/site-mediawiki/updatescript/${::fqdn}/mediawiki_dbupdate.config.rb",
                "puppet:///modules/site-mediawiki/updatescript/mediawiki_dbupdate.config.rb",
                "puppet:///modules/mediawiki/updatescript/mediawiki_dbupdate.config.rb" ],
    require => [ Package['ruby-mysql'], Package['rubygem-highline'] ],
    owner => root, group => 0, mode => 0600;
  }
  file{'/opt/bin/mediawiki_dbupdate.rb':
    source => "puppet:///modules/mediawiki/updatescript/mediawiki_dbupdate.rb",
    require => File['/opt/bin/mediawiki_dbupdate.config.rb'],
    owner => root, group => 0, mode => 0700;
  }
}
