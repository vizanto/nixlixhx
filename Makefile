update-haxe:
	nix-prefetch-git --leave-dotGit --fetch-submodules 'https://github.com/HaxeFoundation/haxe.git' \
		| sed -e 's|\("fetchSubmodules": true\)|\1, "leaveDotGit": true|' > nixpkgs-overlay/haxe.json
