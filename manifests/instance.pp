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
#   - you need to supply an array : ['192.168.1.10','192.168.1.11']
#
# extenstions: extensions to enable for the wiki
#   - default: none
#   - has to be an array of extesions relative to the extensions/ directory:
#       [ 'ext_foobar1', 'ext_foobar2', 'foobar3/ext' ]
#
# language: language of the wiki
#   - default: de
define mediawiki::instance(
  $ensure                   = present,
  $path                     = 'absent',
  $image                    = 'absent',
  $config                   = 'unmanaged',
  $db_server                = 'unmanaged',
  $db_name                  = 'unmanaged',
  $db_user                  = 'db_name',
  $db_pwd                   = 'unmanaged',
  $contact                  = 'unmanaged',
  $sitename                 = 'unmanaged',
  $secret_key               = 'unmanaged',
  $server                   = $name,
  $ssl_mode                 = false,
  $autoinstall              = true,
  $squid_servers            = 'absent',
  $hashed_upload_dir        = true,
  $file_extensions          = 'absent',
  $extensions               = 'absent',
  $language                 = 'de',
  $spam_protection          = false,
  $wiki_options             = {},
  $documentroot_owner       = root,
  $documentroot_group       = apache,
  $documentroot_mode        = 0640,
  $documentroot_write_mode  = 0660
){
  include ::mediawiki

  case $mediawiki::install_src {
    'git': { $basedir = '/var/www/mediawiki' }
    default: { $basedir = '/usr/share/mediawiki' }
  }

  case $path {
    'absent': { $real_path = "/var/www/vhosts/${name}/www" }
    default: { $real_path = $path }
  }

  if ($ensure == 'absent') {
    file{$real_path:
      ensure => absent,
    }
  } else {
    $canonical_server = $ssl_mode ? {
      'force' => "https://${server}",
      'only'  => "https://${server}",
      default => "http://${server}"
    }
    file{
      $real_path:
        ensure        => directory,
        recurse       => true,
        recurselimit  => 1,
        purge         => true,
        force         => true,
        owner         => $documentroot_owner,
        group         => $documentroot_group,
        mode          => $documentroot_mode;
      [ "${real_path}/images", "${real_path}/cache" ]:
        ensure        => directory,
        owner         => $documentroot_owner,
        group         => $documentroot_group,
        mode          => $documentroot_write_mode;
    }

    mediawiki::file{
      [
        "${real_path}/api.php",
        "${real_path}/autoload.php",
        "${real_path}/extensions",
        "${real_path}/img_auth.php",
        "${real_path}/includes",
        "${real_path}/index.php",
        "${real_path}/languages",
        "${real_path}/load.php",
        "${real_path}/mw-config",
        "${real_path}/opensearch_desc.php",
        "${real_path}/profileinfo.php",
        "${real_path}/resources",
        "${real_path}/serialized",
        "${real_path}/skins",
        "${real_path}/thumb_handler.php",
        "${real_path}/thumb.php",
        "${real_path}/vendor",
        "${real_path}/wiki.phtml",
      ]:
        src_path => $basedir;
      "${real_path}/images/.htaccess":
        src_path => "${basedir}/images";
      "${real_path}/cache/.htaccess":
        src_path => "${basedir}/cache";
    }

    if ($image != 'absent') {
      mediawiki::config{$image:
        mediawiki_name  => $name,
        dst_path        => $real_path,
        owner           => $documentroot_owner,
        group           => $documentroot_group,
        mode            => $documentroot_mode;
      }
    } else {
      mediawiki::file{"${real_path}/Wiki.png": src_path => $basedir, }
    }

    if ('Math/Math' in $extensions) or $spam_protection {
      require mediawiki::math
      $latex_fmt_source = $::operatingsystemmajrelease ? {
        5 => '/root/.texmf-var/web2c/latex.fmt',
        6 => '/var/lib/texmf/web2c/pdftex/latex.fmt'
      }
      file{
        "${real_path}/images/tmp":
          ensure  => directory,
          owner   => $documentroot_owner,
          group   => $documentroot_group,
          mode    => $documentroot_write_mode;
        "${real_path}/images/tmp/latex.fmt":
          source  => $latex_fmt_source,
          owner   => $documentroot_owner,
          group   => $documentroot_group,
          mode    => $documentroot_mode;
      }
    }

    case $config {
      'file': {
        mediawiki::config{
          'LocalSettings.php':
            mediawiki_name  => $name,
            dst_path        => $real_path,
            owner           => $documentroot_owner,
            group           => $documentroot_group,
            mode            => $documentroot_mode;
          }
      }
      'template': {
        if ($db_server=='unmanaged') or ($db_name=='unmanaged') or ($db_user=='unmanaged') or ($db_pwd=='unmanaged') or ($contact=='unmanaged') or ($sitename=='unmanaged') or ($secret_key=='unmanaged'){
          fail("you have to set all necessary variables for ${name} on ${::fqdn} to deploy it in template mode! (db_server: ${db_server} - db_name: ${db_name} - db_user: ${db_user} - db_pwd: ${db_pwd} - contact: ${contact} - sitename: ${sitename} - secret_key: ${secret_key})")
        }

        case $secret_key {
          'trocla': { $real_secret_key = trocla("mediawiki_${name}_secret_key",'plain','length: 32') }
          default: { $real_secret_key = $secret_key }
        }
        case $db_user {
          'db_name': { $real_db_user = $db_name }
          default: { $real_db_user = $db_user }
        }
        case $db_pwd {
          'trocla': { $real_db_pwd = trocla("mysql_${real_db_user}",'plain') }
          default: { $real_db_pwd = $db_pwd }
        }

        $std_wiki_options = {
          anyone_can_edit       => false,
          anyone_can_register   => true,
          email_authentication  => false,
        }
        $real_wiki_options = merge($std_wiki_options, $wiki_options)

        file{
          "${real_path}/LocalSettings.php":
            content => template('mediawiki/config/LocalSettings.php.erb'),
            require => Mediawiki::File["${real_path}/index.php"],
            owner   => $documentroot_owner,
            group   => $documentroot_group,
            mode    => $documentroot_mode;
        }
        if $autoinstall {
          $admin_pass = trocla("mediawiki_${name}_admin",'plain')
          exec{"install_mediawiki_${name}":
            command => "php /var/www/mediawiki/maintenance/install.php --dbserver ${db_server} --confpath ${real_path}/LocalSettings.php --dbname ${db_name} --dbuser ${real_db_user} --dbpass '${$real_db_pwd}' --lang ${language} --pass '${admin_pass}' --scriptpath / '${sitename}' admin",
            unless  => "ruby -rrubygems -rmysql -e 'c = Mysql.real_connect(\"${db_server}\",\"${real_db_user}\",\"${real_db_pwd}\",\"${db_name}\"); exit (! c.query(\"SHOW TABLES LIKE \\\"user\\\";\").fetch_row.nil? && c.query(\"SELECT COUNT(user_id) FROM user;\").fetch_row[0].to_i > 0)'",
            require => File["${real_path}/LocalSettings.php"];
          }
        }
      }
    }
  }
}
