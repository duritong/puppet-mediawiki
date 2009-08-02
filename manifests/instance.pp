# mediawiki::instance
#
# Create a mediawiki farm instance
#
# Variables:
#
# image: wether to deploy an image or not.
#   default: no image to deploy, use default
#
# config: the media wiki configs (LocalSettings.php,
#     AdminSettings.php)are either:
#   - unmanaged: no configs, will be created nor deployed.
#   - template: configs will be created from template.
#   - file: configs are supplied by file resource
#
# secret_key: the secret key for cookies etc. have to be set and should be unique
#
# squid_servers: if mediawiki should do caching for squid servers.
#   - default: absent -> no squid caching enabled.
#   - you need to supply and array string: "'192.168.1.10','192.168.1.11'"
#
# extenstions: extensions to enable for the wiki
#   - default: none
#   - have to be a : separated list of extensions relativ to the extensions path, like:
#       "ext_foobar1:ext_foobar2:foobar3/ext"
#
# language: language of the wiki
#   - default: de
define mediawiki::instance(
  $ensure = present,
  $path = 'absent',
  $image = 'absent',
  $config = 'unmanaged',
  $db_server = 'unmanaged',
  $db_name = 'unmanaged',
  $db_user = 'unmanaged',
  $db_pwd = 'unmanaged',
  $contact = 'unmanaged',
  $sitename = 'unmanaged',
  $secret_key = 'unmanaged',
  $squid_servers = 'absent',
  $hashed_upload_dir = true,
  $extensions = 'absent',
  $language = 'de',
  $documentroot_owner = root,
  $documentroot_group = apache,
  $documentroot_mode = 0640,
  $documentroot_write_mode = 0660
){
  include ::mediawiki

  case $mediawiki_install_src {
    'git': { $basedir = '/var/www/mediawiki' }
    default: { $basedir = '/usr/share/mediawiki' }
  }

  case $path {
    'absent': { $real_path = "/var/www/vhosts/${name}/www/" }
    default: { $real_path = $path }
  }

  if ($ensure == 'absent') {
    file{"${real_path}":
      ensure => absent,
    }
  } else {
    file{"${real_path}":
      ensure => directory,
      source => "puppet://$server/common/empty",
      recurse => true,
      purge => true,
      force => true,
      owner => $documentroot_owner, group => $documentroot_group, mode => $documentroot_mode;
    }
    file{ [ "${real_path}/images", "${real_path}/cache" ]:
      ensure => directory,
      owner => $documentroot_owner, group => $documentroot_group, mode => $documentroot_write_mode;
    }

    mediawiki::file{
      [ "${real_path}/languages", "${real_path}/php5.php5", "${real_path}/thumb.php", "${real_path}/img_auth.php",
        "${real_path}/redirect.php", "${real_path}/trackback.php", "${real_path}/includes", "${real_path}/redirect.phtml",
        "${real_path}/wiki.phtml", "${real_path}/index.php", "${real_path}/math", "${real_path}/skins",
        "${real_path}/extensions", "${real_path}/install-utils.inc", "${real_path}/opensearch_desc.php5",
        "${real_path}/serialized", "${real_path}/StartProfiler.php", "${real_path}/trackback.php5" ]:
      src_path => $basedir,
    }

    if ($image != 'absent') {
      mediawiki::config{"${image}":
        mediawiki_name => $name,
        dst_path => $real_path,
        owner => $documentroot_owner, group => $documentroot_group, mode => $documentroot_mode;
      }
    } else {
      mediawiki::file{"${real_path}/Wiki.png": src_path => $basedir, }
    }

    case $config {
      'file': {
        mediawiki::config{
          'AdminSettings.php':
            mediawiki_name => $name,
            dst_path => $real_path,
            owner => root, group => 0, mode => 0400;
          'LocalSettings.php':
            mediawiki_name => $name,
            dst_path => $real_path,
            owner => $documentroot_owner, group => $documentroot_group, mode => $documentroot_mode;
          }
      }
      'template': {
        if ($db_server=='unmanaged') or ($db_name=='unmanaged') or ($db_user=='unmanaged') or ($db_pwd=='unmanaged') or ($contact=='unmanaged') or ($sitename=='unmanaged') or ($secret_key=='unmanaged'){
          fail("you have to set all necessary variables for ${name} on ${fqdn} to deploy it in template mode!")
        }
        file{
          "${real_path}/AdminSettings.php":
            content => template('mediawiki/config/AdminSettings.php.erb'),
            require => Mediawiki::File["${real_path}/index.php"],
            owner => root, group => 0, mode => 0400;
          "${real_path}/LocalSettings.php":
            content => template('mediawiki/config/LocalSettings.php.erb'),
            require => Mediawiki::File["${real_path}/index.php"],
            owner => $documentroot_owner, group => $documentroot_group, mode => $documentroot_mode;
        }
      }
    }
  }
}
