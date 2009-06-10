class mediawiki::git inherits mediawiki::base {
  Package['mediawiki']{
    ensure => absent,
  }

  if $mediawiki_git_src == '' { fail("you need to define \$mediawiki_git_src on ${fqdn}, if you'd like to install mediawiki using git") }

  git::clone{'mediawiki':
    git_repo => $mediawiki_git_src,
    projectroot => '/var/www/mediawiki',
    cloneddir_restrict_mode => false,
  }
}
