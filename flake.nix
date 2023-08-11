{
  inputs = {
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    systems,
    nixpkgs,
    ...
  } @ inputs: let
    eachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    packages = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.writeShellApplication {
        name = "default";
        runtimeInputs = [
          pkgs.git-filter-repo
        ];
        text = ''
          usage() {
            echo "Usage: default <upstream ref>" >&2
          }

          case "$1" in
            -h|--help)
              usage
              exit
               ;;
            \'\')
              usage
              exit 1
               ;;
            *)
              upstream="$1" ;;
          esac

          start="$(git rev-parse HEAD)"
          branch="$(git symbolic-ref --short HEAD)"
          tmp="recipes-$(date +%s)"
          base=$(git merge-base "$upstream" "$start")

          git switch -c "$tmp" "$upstream"

          cleanup() {
            git branch -D "$tmp"
          }

          trap cleanup ERR EXIT

          git filter-repo --path recipes/ --refs "$base..HEAD"
          git rebase "$start"
          git switch "$branch"
          git merge --ff-only "$tmp"
        '';
      };
    });
  };
}
