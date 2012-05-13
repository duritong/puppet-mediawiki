class mediawiki::math {
  require ocaml
  require tetex::dvips
  require tetex::latex
  require tetex::ghostscript
  require make

  exec{
    'generate_texvc':
      command => 'make',
      cwd => '/var/www/mediawiki/extensions/Math/math/',
      creates => '/var/www/mediawiki/extensions/Math/math/texvc',
      requires => Git::Clone['mediawiki'];
    'generalte_latex.fmt':
      command => '/var/www/mediawiki/extensions/Math/math/texvc /tmp /tmp "y=x+2"',
      creates => '/root/.texmf-var/web2c/latex.fmt';
  }
}
