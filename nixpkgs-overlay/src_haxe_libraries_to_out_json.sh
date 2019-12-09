(
  echo '{'
  grep -R '@install' $src/haxe_libraries \
    |sed -E 's~.*?/(.*).hxml:# @install: lix .*?download "?([^ "]+)"? (as|into) (.*)~"\1":{"name":"\1","uri":"\2","dest":"\4"},~';
  echo
  echo '"src":"'$src'"'
  echo '}'
) > $out;
