{
  inputs = {
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    systems,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;
    eachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    packages = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default =
        lib.makeOverridable (
          {commitCallback}:
            pkgs.writeShellApplication {
              name = "default";
              runtimeInputs = [
                pkgs.git-filter-repo
              ];
              text = ''
                usage() {
                  echo "Usage: default <upstream ref>" >&2
                }

                if [[ $# -eq 0 ]]; then
                  usage
                  exit 1
                fi

                case "$1" in
                  -h|--help)
                    usage
                    exit
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

                git filter-repo --path recipes/ --refs "$base..HEAD" ${
                  lib.optionalString (commitCallback != null)
                  ("--commit-callback '\n" + commitCallback + "'")
                }
                git rebase "$start"
                git switch "$branch"
                git merge --ff-only "$tmp"
              '';
            }
        ) {
          # Reset the committer to prevent adding the rewriter's identity.
          # Provided by Иван Жеков at
          # https://github.com/newren/git-filter-repo/issues/379#issuecomment-1182480579
          commitCallback = ''
            commit.committer_name = commit.author_name
            commit.committer_email = commit.author_email
            commit.committer_date = commit.author_date
          '';
        };
    });
  };
}
