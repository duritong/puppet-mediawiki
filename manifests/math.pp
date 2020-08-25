# install math dependencies
class mediawiki::math {
  require ocaml
  require tetex::dvips
  require tetex::latex
  require tetex::ghostscript
}
