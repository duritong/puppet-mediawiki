#
# mediawiki module
#
# Copyright 2009, admin(at)immerda.ch
#
# This program is free software; you can redistribute
# it and/or modify it under the terms of the GNU
# General Public License version 3 as published by
# the Free Software Foundation.
#

# Variables:
# - git_repo: Git Repository from where to install the mediawiki
class mediawiki(
  Stdlib::HTTPSUrl $git_repo = 'https://code.immerda.ch/immerda/managed-apps/mediawiki.git',
) {
  require git
  require ruby::mysql

  file{
    '/usr/local/sbin/upgrade-mediawikis.rb':
      source => 'puppet:///modules/mediawiki/updatescript/mediawiki_dbupdate.rb',
      owner  => root,
      group  => 0,
      mode   => '0700';
  }
}
