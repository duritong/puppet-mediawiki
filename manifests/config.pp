# manage a mediawiki config
define mediawiki::config(
  $mediawiki_name,
  $dst_path,
  $owner,
  $group,
  $mode
){
  file{"${dst_path}/${name}":
    source  => ["puppet:///modules/site_mediawiki/${::fqdn}/${mediawiki_name}/${name}",
                "puppet:///modules/site_mediawiki/${mediawiki_name}/${name}" ],
    require => Mediawiki::File["${dst_path}/index.php"],
    owner   => $owner,
    group   => $group,
    mode    => $mode;
  }
  if str2bool($::selinux) {
    $seltype_rw = $::operatingsystemmajrelease ? {
      '5'     => 'httpd_sys_script_rw_t',
      default => 'httpd_sys_rw_content_t'
    }
    File["${dst_path}/${name}"]{
      seltype => $seltype_rw,
    }
  }
}
