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
# - install_src: The source of mediawiki
#   git: clone it from a git repository (Requires mediawiki_git_repo)
#   default: install it by package
#
# - git_repo: Git Repository from where to install the mediawiki
class mediawiki(
  $install_src = hiera('mediawiki_install_src','package'),
  $git_repo = hiera('mediawiki_git_repo','git://git.immerda.ch/imediawiki.git')
) {
  case $mediawiki::install_src {
    'git': { include mediawiki::git }
    default: { include mediawiki::base }
  }
}
