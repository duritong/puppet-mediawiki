define mediawiki::file(
  $src_path
){
  file{$name:
    ensure => "${src_path}/${name}",
  }
  case $mediawiki_install_src {
    'git': { File[$name]{ require => Git::Clone['mediawiki'], } }
    default: { File[$name]{ require => Package['mediawiki'], } }
  }

}
