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
    seltype => 'httpd_sys_rw_content_t',
    owner   => $owner,
    group   => $group,
    mode    => $mode;
  }
}
