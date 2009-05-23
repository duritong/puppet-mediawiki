define mediawiki::file(
  $src_path
){
  $filename = basename($name)
  file{$name:
    ensure => "${src_path}/${filename}",
  }
  case $mediawiki_install_src {
    'git': { File[$name]{ require => Git::Clone['mediawiki'], } }
    default: { File[$name]{ require => Package['mediawiki'], } }
  }

}
