#!/bin/bash

cd $(dirname $0)

root=/data/mirrors
exclude_list=exclude.txt
retry=1
repos=(*)
bwlimit=1m

fail=()

do_sync_one() {
    set -e
    export DISTRO="$1"

    export TARGET_DIR="$root/$DISTRO"
    export TMP_DIR="$root/.tmp/$DISTRO"
    export LOG_FILE="$root/.log/$DISTRO.log"

    mkdir -p "$TMP_DIR" "$TARGET_DIR" "$root/.lock" "$root/.log"
    touch "$LOG_FILE"
    flock "$root/.lock/$DISTRO.lock" ./sync.sh
}

do_sync_all() {
    local repo
    fail=()
    for repo; do
        [[ ! -x "$repo/sync.sh" ]] && continue
        if ! pushd "$repo" >/dev/null; then
            echo "Can not enter dir $repo"
            continue
        fi

        echo "Syncing $repo"
        if ! su http -s /bin/bash -c "do_sync_one '$repo'" ; then
             echo "$repo failed"
             fail+=("$repo")
        fi

        popd >/dev/null
    done

    return ${#fail[@]}
}

trap 'exit' SIGINT SIGTERM

export EXCLUDE_LIST="$(readlink -f $exclude_list)"
export BWLIMIT="$bwlimit"
export root
export -f do_sync_one

echo "Start syncing..."
while ! do_sync_all "${repos[@]}" && [[ $retry -gt 0 ]]; do
    let retry--
    repos=( "${fail[@]}" )
    echo "Retry sync ${repos[@]}"
done
