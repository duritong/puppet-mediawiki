# manage a mediawiki file
define mediawiki::file(
  $src_path
){
  $filename = basename($name)
  file{$name:
    ensure => "${src_path}/${filename}",
  }
  if str2bool($::selinux) {
    File[$name]{
      # does not need to be writeable
      seltype => 'httpd_sys_content_t',
    }
  }
  case $mediawiki::install_src {
    'git': { File[$name]{ require => Git::Clone['mediawiki'], } }
    default: { File[$name]{ require => Package['mediawiki'], } }
  }

}
