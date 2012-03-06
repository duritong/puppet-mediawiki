class mediawiki::git inherits mediawiki::base {
  Package['mediawiki']{
    ensure => absent,
  }
  git::clone{'mediawiki':
    git_repo => $mediawiki::git_repo,
    projectroot => '/var/www/mediawiki',
    cloneddir_restrict_mode => false,
  }
}
