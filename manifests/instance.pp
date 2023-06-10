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
  Enum['absent','present']
    $ensure                   = present,
  String
    $image                    = 'absent',
  String
    $config                   = 'unmanaged',
  String
    $db_server                = 'unmanaged',
  String
    $db_name                  = 'unmanaged',
  String
    $db_user                  = 'db_name',
  String
    $db_pwd                   = 'unmanaged',
  String
    $contact                  = 'unmanaged',
  String
    $sitename                 = 'unmanaged',
  String
    $secret_key               = 'unmanaged',
  Variant[Boolean,Enum['force']]
    $ssl_mode                 = false,
  Boolean
    $autoinstall              = true,
  Variant[Enum['absent'],Array[String,1]]
    $squid_servers            = 'absent',
  Boolean
    $hashed_upload_dir        = true,
  Boolean
    $spam_protection          = false,
  Variant[Enum['absent'],Array[String,1]]
    $file_extensions          = 'absent',
  Variant[Enum['absent'],Array[String,1]]
    $extensions               = 'absent',
  String
    $language                 = 'de',
  Hash
    $wiki_options             = {},
  Variant[Enum['system'],Pattern[/^scl\d+$/]]
    $php_installation         = 'scl74',
  String
    $documentroot_owner       = root,
  String
    $documentroot_group       = apache,
  Stdlib::Filemode
    $documentroot_mode        = '0640',
  Stdlib::Filemode
    $documentroot_write_mode  = '0660'
){
  include mediawiki

  $path = "/var/www/vhosts/${name}/www"

  if ($wiki_options['nightly_update'] != false) and ($ensure == 'present') {
    $ensure_nightly_update = 'present'
  } else {
    $ensure_nightly_update = 'absent'
  }
  systemd::timer { "mw-update-${name}.timer":
    ensure => $ensure_nightly_update,
  }
  if ($ensure != 'absent') {
    $std_wiki_options = {
      anyone_can_edit      => false,
      anyone_can_register  => true,
      enable_email         => true,
      enable_user_email    => false,
      email_authentication => false,
    }
    $real_wiki_options = merge($std_wiki_options, $wiki_options)

    $server = pick($real_wiki_options['server'],$name)
    $canonical_server = $ssl_mode ? {
      'force' => "https://${server}",
      'only'  => "https://${server}",
      default => "http://${server}"
    }
    git::clone{
      $path:
        git_repo        => $mediawiki::git_repo,
        clone_depth     => 1,
        submodules      => true,
        cloneddir_user  => $documentroot_owner,
        cloneddir_group => $documentroot_group,
    }
    file{
      default:
        ensure => directory,
        owner  => $documentroot_owner,
        group  => $documentroot_group;
      $path:
        mode => $documentroot_mode;
      [ "${path}/images", "${path}/cache" ]:
        require => Git::Clone[$path],
        mode    => $documentroot_write_mode;
    }

    if ($image != 'absent') {
      mediawiki::config{$image:
        mediawiki_name => $name,
        dst_path       => $path,
        owner          => $documentroot_owner,
        group          => $documentroot_group,
        mode           => $documentroot_mode;
      }
    }

    if ('Math/Math' in $extensions) or $spam_protection {
      require mediawiki::math
      $latex_fmt_source = '/var/lib/texmf/web2c/pdftex/latex.fmt'
      file{
        "${path}/images/tmp":
          ensure => directory,
          owner  => $documentroot_owner,
          group  => $documentroot_group,
          mode   => $documentroot_write_mode;
        "${path}/images/tmp/latex.fmt":
          source => $latex_fmt_source,
          owner  => $documentroot_owner,
          group  => $documentroot_group,
          mode   => $documentroot_mode;
      }
    }
    if $config == 'file' {
      mediawiki::config{
        'LocalSettings.php':
          mediawiki_name => $name,
          dst_path       => $path,
          owner          => $documentroot_owner,
          group          => $documentroot_group,
          mode           => $documentroot_mode;
      }
    } elsif $config == 'template' {
      if ($db_server=='unmanaged') or ($db_name=='unmanaged') or ($db_user=='unmanaged') or ($db_pwd=='unmanaged') or ($contact=='unmanaged') or ($sitename=='unmanaged') or ($secret_key=='unmanaged'){
        fail("you have to set all necessary variables for ${name} on ${facts['fqdn']} to deploy it in template mode! (db_server: ${db_server} - db_name: ${db_name} - db_user: ${db_user} - db_pwd: ${db_pwd} - contact: ${contact} - sitename: ${sitename} - secret_key: ${secret_key})")
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

      file{
        "${path}/LocalSettings.php":
          content => template('mediawiki/config/LocalSettings.php.erb'),
          # it does not need to be writeable
          seltype => 'httpd_sys_content_t',
          owner   => $documentroot_owner,
          group   => $documentroot_group,
          mode    => $documentroot_mode;
      }
      if $autoinstall {
        $admin_pass = trocla("mediawiki_${name}_admin",'plain')

        if $php_installation == 'system' {
          $php_bin = 'php'
        } else {
          $php_inst = regsubst($php_installation,'^scl','php')
          require "::php::scl::${php_inst}"
          $scl_name = getvar("php::scl::${php_inst}::scl_name")
          $php_bin = "/usr/bin/scl enable ${scl_name} -- php"
        }
        if 'MW-OAuth2Client' in $extensions {
          require php::composer
          $ext_cmd = "pushd ${path}/extensions/MW-OAuth2Client/vendors/oauth2-client && ${php_bin} -d allow_url_fopen=1 /usr/bin/composer install && popd && "
        } else {
          $ext_cmd = undef
        }
        $install_cmd = "${ext_cmd}${php_bin} ${path}/mainteance/install.php --dbserver ${db_server} --confpath ${path}/LocalSettings.php --dbname ${db_name} --dbuser ${real_db_user} --dbpass '${$real_db_pwd}' --lang ${language} --pass '${admin_pass}' --scriptpath / '${sitename}' admin"
        $php_update_cmd = "${ext_cmd}${php_bin} ${path}/maintenance/update.php --quick --conf ${path}/LocalSettings.php"
        if versioncmp($facts['os']['release']['major'],'9') < 0 {
          $check_db_command = "ruby -rrubygems -rmysql -e 'c = Mysql.real_connect(\"${db_server}\",\"${real_db_user}\",\"${real_db_pwd}\",\"${db_name}\"); exit (! c.query(\"SHOW TABLES LIKE \\\"user\\\";\").fetch_row.nil? && c.query(\"SELECT COUNT(user_id) FROM user;\").fetch_row[0].to_i > 0)'"
        } else {
          $check_db_command = "ruby -rrubygems -rmysql2 -e 'c = Mysql2::Client.new(host: \"${db_server}\",username: \"${real_db_user}\",password: \"${real_db_pwd}\",database: \"${db_name}\"); exit (! c.query(\"SHOW TABLES LIKE \\\"user\\\";\").first.nil? && c.query(\"SELECT COUNT(user_id) FROM user;\").first.values.first.to_i > 0)'"
        }

        Git::Clone[$path] -> File["${path}/LocalSettings.php"]
        exec{"install_mediawiki_${name}":
          environment => "MW_INSTALL_PATH=${path}",
          command     => $install_cmd,
          unless      => $check_db_command,
          require     => File["${path}/LocalSettings.php"];
        } -> file{"/var/www/vhosts/${name}/data/php_update_command":
          content => $php_update_cmd,
          owner   => root,
          group   => 0,
          mode    => '0644';
        }
        if $db_server in ['localhost','127.0.0.1','::1'] {
          Mysql_database<| title == $db_name |>  -> Exec["install_mediawiki_${name}"]
          Mysql_user<| title == $real_db_user |> -> Exec["install_mediawiki_${name}"]
        }
      }

      if $ensure_nightly_update == 'present' {
        require systemd::mail_on_failure
        $update_timer_params = pick($wiki_options['nightly_update_timer'],{})
        $update_service_params = pick($wiki_options['nightly_update_service'],{}) + {
          name => $name,
        }
        Systemd::Timer["mw-update-${name}.timer"] {
          timer_content   => epp('mediawiki/nightly_update.timer.epp', $update_timer_params),
          service_content => epp('mediawiki/nightly_update.service.epp', $update_service_params),
          active          => true,
          enable          => true,
        }
      }
    }
  }
}
