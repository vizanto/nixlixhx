update-haxe:
	nix-prefetch-git --leave-dotGit --fetch-submodules 'https://github.com/HaxeFoundation/haxe.git' \
		| sed -e 's|\("fetchSubmodules": true\)|\1, "leaveDotGit": true|' > nixpkgs-overlay/haxe.json

update-haxeshim:
	nix-prefetch-git 'https://github.com/lix-pm/haxeshim.git' \
		| sed -e 's|\("fetchSubmodules": false\)|\1, "leaveDotGit": false|' > nixpkgs-overlay/haxeshim.json
	nix-prefetch-git 'https://github.com/lix-pm/lix.client.git' \
		| sed -e 's|\("fetchSubmodules": false\)|\1, "leaveDotGit": false|' > nixpkgs-overlay/lix.json
