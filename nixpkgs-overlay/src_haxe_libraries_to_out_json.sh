(
  echo '{'
  grep -R '@install' $src/haxe_libraries \
    |sed -E 's|.*?/(.*).hxml:# @install: lix --silent download ([^ ]+) into (.*)|"\1":{"name":"\1","uri":\2,"dest":"\3"},|';
  echo
  echo '"src":"'$src'"'
  echo '}'
) > $out;
