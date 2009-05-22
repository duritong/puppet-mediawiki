define mediawiki::config(
  $mediawiki_name,
  $dst_path,
  $owner,
  $group,
  $mode
){
  file{"${dst_path}/$name":
    source => [ "puppet://$server/files/mediawiki/${fqdn}/${mediawiki_name}/${name}",
                "puppet://$server/files/mediawiki/${mediawiki_name}/${name}" ],
    require => Mediawiki::File["${dst_path}/index.php"],
    owner => $owner, group => $group, mode => $mode;
  }
}
